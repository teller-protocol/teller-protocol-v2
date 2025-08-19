import * as path from "path";

import AppEth from "@ledgerhq/hw-app-eth";
import Transport from "@ledgerhq/hw-transport-node-hid";
import { Mutex } from "async-mutex";
import axios from "axios";
import { makeNodeDisklet } from "disklet";
import { makeMemlet } from "memlet";

import { Logger } from "../../utils/logger";
import { SocketEmitter, SocketEvent } from "../../websocket/SocketEmitter";
import { auth } from "../commands/auth";
import * as websocket from "../ws";

import { IApiArgs, InnerAPI, SubgraphVersion, VersionUpdate } from "./index";


const SAVE_LOAD_COOKIE = false;

const mutex = new Mutex();

interface INetworkConfig {
  name: string;
  network: string;
  owner: {
    address: string;
    network: string;
  };
  socketEmitter?: SocketEmitter;
  logger?: Logger;
}

const Network: Record<string, number> = {
  mainnet: 1,
  "arbitrum-one": 42161
};

export const makeStudio = async (
  networkConfig: INetworkConfig
): Promise<InnerAPI> => {
  const disklet = makeNodeDisklet(path.join(__dirname, "./config"));
  const memlet = makeMemlet(disklet);

  interface IConfig {
    
    networkWallets:{ [owner:string] : IDeployKeyConfig}
    [owner: string]: IOwnerConfig | undefined;
  }
  interface IOwnerConfig {
    Cookie?: {
      value: string;
      expiration: string;
    };
    deployKey?: string;
  }
  interface IDeployKeyConfig {
    
    deployKey: string;
    network: string;
  }




  const getStudioConfig = async (): Promise<IConfig> => {
    return await memlet.getJson("studio.json").catch(() => ({}));
  };
  let studioConfig = await getStudioConfig();

  //deprecated -- dont use cookies 
  /*
  const setConfig = async (_config: IConfig): Promise<void> => {
    studioConfig = _config;
    await memlet.setJson("studio.json", _config);
  };*/

  const api = axios.create({
    baseURL: "https://api.studio.thegraph.com/graphql",
    withCredentials: true,
    transformResponse: (dataStr: string) => {
      const data: {
        errors?: Array<{
          message: string;
          locations: Array<{ line: number; column: number }>;
          path: string[];
          extensions: { code: string };
        }>;
        data?: any;
      } = JSON.parse(dataStr);
      if (data.errors) {

        console.log(data.errors)

        const messages = data.errors.map(e => {
          if (e.extensions.code === "UNAUTHENTICATED") {
            const prev = studioConfig[networkConfig.owner.address] ?? {};
            studioConfig[networkConfig.owner.address] = {
              ...prev,
              Cookie: undefined
            };
         //   void setConfig(studioConfig);
          }
          return `\t* ${e.message}`;
        });
        networkConfig.logger?.error(`Studio API errors:\n${messages}`);
        // throw new AggregateError(
        //   data.errors,
        //   `Studio API errors:\n${messages}`
        // );
      }
      return data;
    }
  });

  const socket = await websocket.create(
    "wss://api.studio.thegraph.com/graphql",
    {
      emitter: networkConfig.socketEmitter,
      logger: networkConfig.logger
    }
  );

  const getCurrentUser = async (): Promise<any> => {
    await login();

    const res = await api.post("", {
      operationName: "currentUser",
      variables: {},
      query:
        "fragment AuthUserFragment on User {\n  ethAddress\n  emailAddress\n  deployKey\n  firstLogin\n  isSubsidizedQueriesEligible\n  subsidizedQueriesRemaining\n  queryStatus\n  totalUnpaidInvoiceAmount\n  subgraphsCount\n  ongoingInvoice {\n    totalQueryFees\n    billingPeriodStartsAt\n    billingPeriodEndsAt\n }\n}\n\nquery currentUser {\n  currentUser {\n    ...AuthUserFragment\n}\n}"
    });
    return res.data.data.currentUser;
  };

  const login = async (): Promise<void> => {
    await mutex.runExclusive(async () => {
      if (!socket.isConnected()) await socket.connect();

      let cookie: string | null = null;
      const Cookie = studioConfig[networkConfig.owner.address]?.Cookie;
     

      if (Cookie && SAVE_LOAD_COOKIE) {
        if (new Date(Cookie.expiration).getTime() > Date.now()) {
          cookie = Cookie.value;
        } else {
          networkConfig.logger?.log("Cookie expired, logging in again");
        }
      } else {
        networkConfig.logger?.log(
          "Not logged in, attempting to log in via ledger..."
        );
      }

      if (!cookie) {
        const transport = await Transport.open("");
        const eth = new AppEth(transport);
        
        let knownAddress = "0xF3E864eAaFf9Cf2cD21A862d51D875093b4B5baA"

        let foundPath = undefined
        let foundAddress = undefined

        for( let i =0; i< 99 ; i++) {

          const path = `44'/60'/0'/0/${i.toString()}`;
          console.log("searching ", path)
          const { address: addressAtPath } = await eth.getAddress(path);
          
          console.log({addressAtPath})
          if(addressAtPath == knownAddress){
            foundAddress = addressAtPath; 
            foundPath = path;
            break
          }
        }

        if( !foundPath || !foundAddress) {

          throw new Error("Could not find path")
        }

       // const path = "44'/60'/0'/0/0";
       // const { address } = await eth.getAddress(path);

        const message =
          "Sign this message to prove you have access to this wallet in order to sign in to thegraph.com/studio.\n\n" +
          "This won't cost you any Ether.\n\n" +
          `Timestamp: ${Date.now()}`;

        const sig = await eth.signPersonalMessage(
          foundPath,
          Buffer.from(message).toString("hex")
        );
        const signature = `0x${sig.r}${sig.s}${sig.v.toString(16)}`;

        await transport.close();

        const login = await api.post("", {
          operationName: "login",
          variables: {
            ethAddress: networkConfig.owner.address,
            message,
            signature,
            multisigOwnerAddress: foundAddress,
            networkId: Network[networkConfig.owner.network]
          },
          query:
            "fragment AuthUserFragment on User { id } mutation login($ethAddress: String!, $message: String!, $signature: String!, $multisigOwnerAddress: String, $networkId: Int) { login(ethAddress: $ethAddress, message: $message, signature: $signature, multisigOwnerAddress: $multisigOwnerAddress, networkId: $networkId) { ...AuthUserFragment } }"
        });

        // extract cookie info
        const cookieRegex = /^(SubgraphStudioAPI=[^\s]+;).*Expires=([^;]+);/;
        const cookieRaw = login.headers["set-cookie"]?.find(cookie =>
          cookieRegex.test(cookie)
        );
        if (cookieRaw) {
          const [_, cookieValue, cookieExpiration] = cookieRaw.match(
            cookieRegex
          )!;
          //store this in mem !? 
         /* await setConfig({
            ...studioConfig,
            [networkConfig.owner.address]: {
              ...studioConfig[networkConfig.owner.address],
           //   Cookie: {
           //   value: cookieValue,
           //    expiration: cookieExpiration
           //  }
            }
          });*/
          cookie = cookieValue;
        }
      }

      api.defaults.headers.Cookie = cookie;
    });
  };

  interface StudioSubgraph {
    name: string;
    createdAt: string;
    versions: Array<{
      indexedNetworkChainUID: string;
      publishStatus?: string;
    }>;
    publishedSubgraphs: Array<{
      networkChainUID: string;
    }>;
    lastVersionCreatedAt: string;
  }
  const getSubgraphs = async (): Promise<string[]> => {
    await login();

    const res = await api.post<{
      data: { authUserSubgraphs: StudioSubgraph[] };
    }>("", {
      operationName: "AuthUserSubgraphs",
      variables: {},
      query:
        "query AuthUserSubgraphs {\n  authUserSubgraphs {\n    name\n    createdAt\n    versions {\n      label\n indexedNetworkChainUID\n      publishStatus\n }\n    publishedSubgraphs {\n      networkChainUID\n }\n    lastVersionCreatedAt\n }\n}"
    });
    const subgraphs = res.data?.data?.authUserSubgraphs ?? [];
    return subgraphs.map(subgraph => subgraph.name);
  };

  interface StudioSubgraphVersion {
    id: number;
    label: string;
    network: string;
    deploymentId: string;
    queryUrl: string;
    latestEthereumBlockNumber: number;
    totalEthereumBlocksCount: number;
    failed: boolean;
    synced: boolean;
    publishStatus: string;
  }
  const getLatestVersion = async (
    index = 0
  ): Promise<SubgraphVersion | undefined> => {
    await login();

    const response = await api.post<{
      data: { subgraph: { versions: StudioSubgraphVersion[] } };
    }>("", {
      operationName: "Subgraph",
      variables: {
        name: networkConfig.name
      },
      query: `
      query Subgraph($name: String!) {
        subgraph(name: $name) {
          userId
          name
          latestVersionQueryURL
          versions {
            id
            label
            network
            deploymentId
            queryUrl
            latestEthereumBlockNumber
            totalEthereumBlocksCount
            failed
            synced
            publishStatus
          }
        }
      }
    `
    });
    const subgraph = response.data.data.subgraph;
    const latest = subgraph?.versions
      ?.filter(v => v.network === networkConfig.network && !v.failed)
      ?.sort((a, b) => b.id - a.id)?.[index];
    if (latest) {
      return {
        id: latest.id,
        label: latest.label,
        deploymentId: latest.deploymentId,
        latestEthereumBlockNumber: latest.latestEthereumBlockNumber,
        totalEthereumBlocksCount: latest.totalEthereumBlocksCount,
        failed: latest.failed,
        synced: latest.synced
      };
    }
  };

  const watchVersionUpdate = (
    versionId: number,
    cb: (
      version: VersionUpdate,
      unsubscribe: () => void
    ) => Promise<void> | void
  ): void => {
    networkConfig.socketEmitter?.on(SocketEvent.CONNECTION_CLOSE, () => {
      watchVersionUpdate(versionId, cb);
    });
    return socket.subscribe({
      cb,
      message: {
        type: "subscribe",
        payload: {
          variables: {
            versionId
          },
          operationName: "OnVersionUpdate",
          query:
            "subscription OnVersionUpdate($versionId: Int!) {\n  subgraphVersion(id: $versionId) {\n    latestEthereumBlockNumber\n    totalEthereumBlocksCount\n    synced\n    failed\n}\n}"
        }
      },
      cleaner: (raw: any) => {
        return raw.payload.data.subgraphVersion;
      }
    });
  };

  const apiArgs: IApiArgs = {
    ipfs() {
      return ["--ipfs", "https://api.thegraph.com/ipfs/api/v0"];
    },
    node() {
      return [];
    },
    product() {
      return ["--studio"];
    }
  };

  return {
    getLatestVersion,
    watchVersionUpdate,
    beforeDeploy: async () => {

      console.log(studioConfig)

      console.log(networkConfig.owner.address)

      const deployKey = studioConfig["networkWallets"][networkConfig.owner.address]?.deployKey;
      if (!deployKey) throw new Error("No deploy key found");

      await auth({
        apiArgs,
        deployKey,
        logger: networkConfig.logger
      });
    },
    args: apiArgs
  };
};