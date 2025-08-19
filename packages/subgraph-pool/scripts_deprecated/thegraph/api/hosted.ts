import path from "path";

import axios from "axios";
import { makeNodeDisklet } from "disklet";
import { makeMemlet } from "memlet";

import { Logger } from "../../utils/logger";
import { auth } from "../commands/auth";

import { IApiArgs, InnerAPI, SubgraphVersion, VersionUpdate } from "./index";

enum Version {
  pending,
  current
}

interface ISubgraphConfig {
  name: string;
  network: string;
  logger?: Logger;
}

export const makeHosted = async (
  config: ISubgraphConfig
): Promise<InnerAPI> => {
  const api = axios.create({
    baseURL: `https://api.thegraph.com/index-node/graphql`,
    withCredentials: true
  });

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
      chainHeadBlock?: {
        number: string;
      };
      earliestBlock?: {
        number: string;
      };
      latestBlock?: {
        number: string;
      };
      lastHealthyBlock?: {
        number: string;
      };
    }>;
    entityCount: string;
    node: string;
  }
  const getLatestVersion = async (
    index = Version.pending
  ): Promise<SubgraphVersion | undefined> => {
    if (index > Version.current) return;

    const version = await getVersion(index);
    if (!version) {
      return await getVersion(index + 1);
    }
    return version;
  };

  const getVersion = async (
    versionId: Version
  ): Promise<SubgraphVersion | undefined> => {
    const response = await api.post<{
      data: { version: ISubgraphIndexingStatus };
    }>("", {
      variables: {
        subgraphName: config.name
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
      const chain = indexingStatus.chains.find(
        chain => chain.network === config.network
      );
      if (!chain) throw new Error(`Invalid chain: ${config.network}`);
      return {
        id: versionId,
        deploymentId: indexingStatus.subgraph,
        latestEthereumBlockNumber:
          chain.latestBlock && parseInt(chain.latestBlock.number),
        totalEthereumBlocksCount:
          chain.chainHeadBlock && parseInt(chain.chainHeadBlock.number),
        failed: indexingStatus.health === "failed",
        synced: indexingStatus.synced
      };
    }
  };

  const watchVersionUpdate = (
    versionId: Version,
    _cb: (
      version: VersionUpdate,
      unsubscribe: () => void
    ) => Promise<void> | void
  ): void => {
    const intervalId = setInterval(() => {
      void getVersion(versionId).then(version => {
        if (
          version &&
          version.latestEthereumBlockNumber !== undefined &&
          version.totalEthereumBlocksCount !== undefined
        ) {
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

  const apiArgs: IApiArgs = {
    ipfs() {
      return [];
    },
    node() {
      return [];
    },
    product() {
      return ["--product hosted-service"];
    }
  };
  return {
    getLatestVersion,
    watchVersionUpdate,
    beforeDeploy: async () => {
      const disklet = makeNodeDisklet(path.join(__dirname, "./config"));
      const memlet = makeMemlet(disklet);
      const hostedConfig = await memlet
        .getJson("hosted.json")
        .catch(() => ({}));

      const deployKey = hostedConfig.deployKey;
      if (!deployKey) throw new Error("No deploy key found");

      await auth({
        apiArgs,
        deployKey,
        logger: config.logger
      });
    },
    args: apiArgs
  };
};
