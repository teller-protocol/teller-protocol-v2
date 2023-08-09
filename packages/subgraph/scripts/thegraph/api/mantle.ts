import * as path from "path";

import axios, { Axios } from "axios";
import { makeNodeDisklet } from "disklet";
import { makeMemlet } from "memlet";

import { getNetworkFromName } from "../utils/getNetworkFromName";

import { InnerAPI, SubgraphVersion, VersionUpdate } from "./index";

const disklet = makeNodeDisklet(path.join(__dirname, "./config"));
const memlet = makeMemlet(disklet);

interface IConfig {
  Cookie?: {
    value: string;
    expiration: string;
  };
}
const getConfig = async (): Promise<IConfig> => {
  return await memlet.getJson("aws.json").catch(() => ({}));
};

const setConfig = async (_config: IConfig): Promise<void> => {
  await memlet.setJson("aws.json", _config);
};

enum Version {
  pending,
  current
}

const getDomain = (name: string): string => {
  const subdomain = name.endsWith("-testnet") ? "testnet." : "";
  return `${subdomain}mantle.xyz`;
};

const _apis = new Map<string, Axios>([
  [
    "tellerv2-mantle-testnet",
    axios.create({
      baseURL: "https://graph.testnet.mantle.xyz/graphql",
      withCredentials: true
    })
  ]
]);
const getApi = (name: string): Axios => {
  const api = _apis.get(name);
  if (!api) {
    throw new Error(`No API for subgraph ${name}`);
  }
  return api;
};

export const makeMantle = async (): Promise<InnerAPI> => {
  const config = await getConfig();

  const getSubgraphs = async (): Promise<string[]> => {
    return Array.from(_apis.keys());
  };

  interface ISubgraphIndexingStatus {
    subgraph: string;
    synced: boolean;
    health: string;
    fatalError: {
      message: string;
      block: {
        number: string;
      };
      handler: string;
      deterministic: boolean;
    };
    nonFatalErrors: {
      message: string;
      block: {
        number: number;
      };
      handler: string;
      deterministic: boolean;
    };
    chains: Array<{
      network: string;
      chainHeadBlock: {
        number: string;
      };
      earliestBlock: {
        number: string;
      };
      latestBlock: {
        number: string;
      };
      lastHealthyBlock: {
        number: string;
      };
    }>;
    entityCount: string;
    node: string;
  }
  const getLatestVersion = async (
    name: string
  ): Promise<SubgraphVersion | undefined> => {
    let version = await getVersion(name, Version.pending);
    if (!version) {
      version = await getVersion(name, Version.current);
    }
    return version;
  };

  const getVersion = async (
    name: string,
    versionId: Version
  ): Promise<SubgraphVersion | undefined> => {
    const response = await getApi(name).post<{
      data: { version: ISubgraphIndexingStatus };
    }>("", {
      variables: {
        subgraphName: name
      },
      query: `
      query Subgraph($subgraphName: String!) {
        version: indexingStatusFor${
          versionId === Version.pending ? "Pending" : "Current"
        }Version(subgraphName: $subgraphName) {
          subgraph
          synced
          health
          nonFatalErrors {
            message
            block {
              number
            }
            handler
            deterministic
          }
          chains {
            network
            chainHeadBlock {
              number
            }
            earliestBlock {
              number
            }
            latestBlock {
              number
            }
            lastHealthyBlock {
              number
            }
          }
          entityCount
          node
        }
      }
    `
    });
    const indexingStatus = response.data?.data?.version;
    if (indexingStatus) {
      const _network = getNetworkFromName(name);
      const network = _network.replace("mantle-testnet", "testnet");
      const chain = indexingStatus.chains.find(
        chain => chain.network === network
      );
      if (!chain) throw new Error(`Invalid chain: ${network}`);
      return {
        id: versionId,
        deploymentId: indexingStatus.subgraph,
        latestEthereumBlockNumber: parseInt(chain.latestBlock.number),
        totalEthereumBlocksCount: parseInt(chain.chainHeadBlock.number),
        failed: indexingStatus.health === "failed",
        synced: indexingStatus.synced
      };
    }
  };

  const watchVersionUpdate = (
    name: string,
    versionId: Version,
    _cb: (
      version: VersionUpdate,
      unsubscribe: () => void
    ) => Promise<void> | void
  ): void => {
    const intervalId = setInterval(() => {
      void getVersion(name, versionId).then(version => {
        if (version) {
          void _cb(
            {
              latestEthereumBlockNumber: version.latestEthereumBlockNumber,
              totalEthereumBlocksCount: version.totalEthereumBlocksCount,
              synced: version.synced,
              failed: version.failed
            },
            () => clearInterval(intervalId)
          );
        }
      });
    }, 5000);
  };

  return {
    getSubgraphs,
    getLatestVersion,
    watchVersionUpdate,
    args: {
      ipfs(name: string) {
        return ["--ipfs", `https://ipfs.${getDomain(name)}`];
      },
      node(name: string) {
        return ["--node", `https://graph.${getDomain(name)}/deploy`];
      },
      product(name: string) {
        return [];
      }
    }
  };
};
