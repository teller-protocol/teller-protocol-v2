import * as path from "path";

import AppEth from "@ledgerhq/hw-app-eth";
import Transport from "@ledgerhq/hw-transport-node-hid";
import axios from "axios";
import { makeNodeDisklet } from "disklet";
import { makeMemlet } from "memlet";

import { Logger } from "../../utils/logger";
import { SocketEmitter, SocketEvent } from "../../websocket/SocketEmitter";
import * as websocket from "../ws";

import { InnerAPI, SubgraphVersion, VersionUpdate } from "./index";

interface IStudioConfig {
  socketEmitter?: SocketEmitter;
  logger?: Logger;
}

export const makeStudio = async (
  studioConfig?: IStudioConfig
): Promise<InnerAPI> => {
  const disklet = makeNodeDisklet(path.join(__dirname, "./config"));
  const memlet = makeMemlet(disklet);

  interface IConfig {
    Cookie?: {
      value: string;
      expiration: string;
    };
  }
  const getConfig = async (): Promise<IConfig> => {
    return await memlet.getJson("studio.json").catch(() => ({}));
  };
  let config = await getConfig();

  const setConfig = async (_config: IConfig): Promise<void> => {
    config = _config;
    await memlet.setJson("studio.json", _config);
  };

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
        const messages = data.errors.map(e => {
          if (e.extensions.code === "UNAUTHENTICATED") {
            config.Cookie = undefined;
            void setConfig(config);
          }
          return `\t* ${e.message}`;
        });
        console.error(`Studio API errors:\n${messages}`);
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
      emitter: studioConfig?.socketEmitter,
      logger: studioConfig?.logger
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

  const login = async (reauth = false): Promise<void> => {
    let cookie: string | null = null;
    if (!reauth && config.Cookie) {
      if (new Date(config.Cookie.expiration).getTime() > Date.now()) {
        cookie = config.Cookie.value;
      } else {
        console.log("Cookie expired, logging in again");
      }
    } else {
      console.log("Not logged in, attempting to log in via ledger...");
    }

    if (!cookie) {
      const transport = await Transport.open("");
      const eth = new AppEth(transport);

      const path = "44'/60'/0'/0/0";
      const { address } = await eth.getAddress(path);

      const message =
        "Sign this message to prove you have access to this wallet in order to sign in to thegraph.com/studio.\n\n" +
        "This won't cost you any Ether.\n\n" +
        `Timestamp: ${Date.now()}`;

      const sig = await eth.signPersonalMessage(
        path,
        Buffer.from(message).toString("hex")
      );
      const signature = `0x${sig.r}${sig.s}${sig.v.toString(16)}`;

      await transport.close();

      const login = await api.post("", {
        operationName: "login",
        variables: {
          ethAddress: "0x1a2baa2257343119fb03fd448622456a0c4f2190",
          message,
          signature,
          multisigOwnerAddress: address,
          networkId: 1
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
        await setConfig({
          Cookie: {
            value: cookieValue,
            expiration: cookieExpiration
          }
        });
        cookie = cookieValue;
      }
    }

    api.defaults.headers.Cookie = cookie;
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
    deploymentId: string;
    queryUrl: string;
    latestEthereumBlockNumber: number;
    totalEthereumBlocksCount: number;
    failed: boolean;
    synced: boolean;
    publishStatus: string;
  }
  const getLatestVersion = async (
    name: string,
    index = 0
  ): Promise<SubgraphVersion | undefined> => {
    await login();

    const response = await api.post<{
      data: { subgraph: { versions: StudioSubgraphVersion[] } };
    }>("", {
      operationName: "Subgraph",
      variables: {
        name
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
            deploymentId
            queryUrl
            latestEthereumBlockNumber
            totalEthereumBlocksCount
            failed
            synced
            publishStatus
          }
        }
        authUserSubgraphs {
          name
        }
      }
    `
    });
    const subgraph = response.data.data.subgraph;
    const latest = subgraph?.versions?.sort((a, b) => b.id - a.id)?.[index];
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
    name: string,
    versionId: number,
    cb: (
      version: VersionUpdate,
      unsubscribe: () => void
    ) => Promise<void> | void
  ): void => {
    studioConfig?.socketEmitter?.on(SocketEvent.CONNECTION_CLOSE, () => {
      watchVersionUpdate(name, versionId, cb);
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

  return {
    getSubgraphs,
    getLatestVersion,
    watchVersionUpdate,
    args: {
      ipfs(name: string) {
        return ["--ipfs", "https://api.thegraph.com/ipfs/api/v0"];
      },
      node(name: string) {
        return [];
      },
      product(name: string) {
        return ["--product", "subgraph-studio"];
      }
    }
  };
};
