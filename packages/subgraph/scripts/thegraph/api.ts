import * as path from "path";

import AppEth from "@ledgerhq/hw-app-eth";
import Transport from "@ledgerhq/hw-transport-node-hid";
import axios from "axios";
import { makeNodeDisklet } from "disklet";
import { makeMemlet } from "memlet";

import * as websocket from "./ws";

export interface Subgraph {
  id: number;
  name: string;
  displayName: string;
  status: string[];
  imageUrl: string;
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

export interface SubgraphVersion {
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

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export const makeStudio = async () => {
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
    headers: {
      Cookie: config.Cookie?.value
    }
  });

  const socket = await websocket.create(
    "wss://api.studio.thegraph.com/graphql",
    "studio"
  );

  const getCurrentUser = async (): Promise<any> => {
    await login();

    const res = await api.post("", {
      operationName: "currentUser",
      variables: {},
      query:
        "fragment AuthUserFragment on User {\n  id\n  ethAddress\n  emailAddress\n  deployKey\n  firstLogin\n  isSubsidizedQueriesEligible\n  subsidizedQueriesRemaining\n  queryStatus\n  totalUnpaidInvoiceAmount\n  subgraphsCount\n  ongoingInvoice {\n    totalQueryFees\n    billingPeriodStartsAt\n    billingPeriodEndsAt\n    __typename\n  }\n  __typename\n}\n\nquery currentUser {\n  currentUser {\n    ...AuthUserFragment\n    __typename\n  }\n}"
    });
    return res.data.data.currentUser;
  };

  const login = async (): Promise<void> => {
    if (api.defaults.headers.Cookie) {
      if (new Date(config.Cookie?.expiration).getTime() > Date.now()) {
        return;
      }
      console.log("Cookie expired, logging in again");
    } else {
      console.log("Not logged in, attempting to log in via ledger...");
    }

    const transport = await Transport.open("");
    const eth = new AppEth(transport);

    const path = "44'/60'/0'/0/0";
    const { address } = await eth.getAddress(path);

    const message = `Sign this message to prove you have access to this wallet in order to sign in to thegraph.com/studio.

This won't cost you any Ether.

Timestamp: ${Date.now()}`;

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
    const cookieRegex = /^(SubgraphStudioAPI=[^\s]+;)/;
    const cookie = login.headers["set-cookie"].find(cookie =>
      cookieRegex.test(cookie)
    );
    const cookieValue = cookie.match(cookieRegex)[1];
    const cookieExpiration = /Expires=([^;]+);/.exec(cookie)[1];
    await setConfig({
      Cookie: {
        value: cookieValue,
        expiration: cookieExpiration
      }
    });

    api.defaults.headers.Cookie = cookieValue;
  };

  const getUserSubgraphs = async (): Promise<Subgraph[]> => {
    await login();

    const res = await api.post<{ data: { authUserSubgraphs: Subgraph[] } }>(
      "",
      {
        operationName: "AuthUserSubgraphs",
        variables: {},
        query:
          "query AuthUserSubgraphs {\n  authUserSubgraphs {\n    id\n    name\n    displayName\n    status\n    imageUrl\n    createdAt\n    versions {\n      label\n indexedNetworkChainUID\n      publishStatus\n      __typename\n    }\n    publishedSubgraphs {\n      networkChainUID\n      __typename\n    }\n    lastVersionCreatedAt\n    __typename\n  }\n}"
      }
    );
    return res.data.data.authUserSubgraphs;
  };

  const getLatestVersion = async (
    name: string
  ): Promise<SubgraphVersion | null> => {
    await login();

    const response = await api.post<{
      data: { subgraph: { versions: SubgraphVersion[] } };
    }>("", {
      operationName: "Subgraph",
      variables: {
        name
      },
      query: `
      query Subgraph($name: String!) {
        subgraph(name: $name) {
          id
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
          id
          name
          status
        }
      }
    `
    });
    const subgraph = response.data.data.subgraph;
    return subgraph.versions.sort((a, b) => b.id - a.id)[0];
  };

  interface VersionUpdate {
    network: string;
    latestEthereumBlockNumber: number;
    totalEthereumBlocksCount: number;
    synced: boolean;
    failed: boolean;
  }
  const watchVersionUpdate = (
    versionId: number,
    cb: (
      version: VersionUpdate,
      unsubscribe: () => void
    ) => Promise<void> | void
  ): void => {
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
            "subscription OnVersionUpdate($versionId: Int!) {\n  subgraphVersion(id: $versionId) {\n    network\n    latestEthereumBlockNumber\n    totalEthereumBlocksCount\n    synced\n    failed\n    __typename\n  }\n}"
        }
      },
      cleaner: (raw: any) => {
        return raw.payload.data.subgraphVersion;
      }
    });
  };

  const waitForVersionSync = (versionId: number): Promise<VersionUpdate> => {
    return new Promise((resolve, reject) => {
      watchVersionUpdate(versionId, (version, unsubscribe) => {
        console.log("version update:", JSON.stringify(version, null, 2));
        if (version.failed) {
          unsubscribe();
          reject(`Version "${versionId} failed`);
        } else if (version.synced) {
          unsubscribe();
          resolve(version);
        }
      });
    });
  };

  return {
    getCurrentUser,
    login,
    getUserSubgraphs,
    getLatestVersion,
    watchVersionUpdate,
    waitForVersionSync
  };
};
