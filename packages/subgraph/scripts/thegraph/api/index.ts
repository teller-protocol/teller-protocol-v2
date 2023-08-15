import { Logger } from "../../utils/logger";

import { makeMantle } from "./mantle";
import { makeStudio } from "./studio";

export interface SubgraphVersion {
  id: number;
  label?: string;
  deploymentId: string;
  latestEthereumBlockNumber: number;
  totalEthereumBlocksCount: number;
  failed: boolean;
  synced: boolean;
}

export interface VersionUpdate {
  latestEthereumBlockNumber: number;
  totalEthereumBlocksCount: number;
  synced: boolean;
  failed: boolean;
}

type VersionUpdateCallback = (
  version: VersionUpdate,
  unsubscribe: () => void
) => Promise<void> | void;

export interface InnerAPI {
  getSubgraphs: () => Promise<string[]>;
  getLatestVersion: (
    name: string,
    index?: number
  ) => Promise<SubgraphVersion | null | undefined>;
  watchVersionUpdate: (
    name: string,
    versionId: number,
    cb: VersionUpdateCallback
  ) => void;

  args: {
    ipfs: (name: string) => string[];
    node: (name: string) => string[];
    product: (name: string) => string[];
  };
}
export interface API extends InnerAPI {
  waitForVersionSync: (
    name: string,
    versionId: number,
    cb?: VersionUpdateCallback
  ) => Promise<VersionUpdate>;
}

interface APIConfig {
  logger?: Logger;
}

export const makeApi = async (config?: APIConfig): Promise<API> => {
  const studio = await makeStudio({
    logger: config?.logger
  });
  const aws = await makeMantle({
    logger: config?.logger
  });

  const nameMap = new Map<string, InnerAPI>();
  const getSubgraphApi = (name: string): InnerAPI => {
    const api = nameMap.get(name);
    if (!api) throw new Error(`API for ${name} does not exist`);
    return api;
  };
  const mapSubgraphApis = async (api: InnerAPI): Promise<string[]> => {
    const names = await api.getSubgraphs();
    for (const name of names) {
      if (nameMap.has(name)) {
        throw new Error(`API for ${name} already exists`);
      }
      nameMap.set(name, api);
    }
    return names;
  };

  const getSubgraphs = (): Promise<string[]> => {
    return Promise.all([
      mapSubgraphApis(studio),
      mapSubgraphApis(aws)
    ]).then(s => s.flat());
  };

  const getLatestVersion = (
    name: string,
    index = 0
  ): Promise<SubgraphVersion | null | undefined> => {
    const api = getSubgraphApi(name);
    return api.getLatestVersion(name, index);
  };

  const watchVersionUpdate = (
    name: string,
    versionId: number,
    cb: VersionUpdateCallback
  ): void => {
    const api = getSubgraphApi(name);
    api.watchVersionUpdate(name, versionId, cb);
  };

  const waitForVersionSync = (
    name: string,
    versionId: number,
    cb?: VersionUpdateCallback
  ): Promise<VersionUpdate> => {
    return new Promise((resolve, reject) => {
      watchVersionUpdate(name, versionId, (version, unsubscribe) => {
        void cb?.(version, unsubscribe);

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
    getSubgraphs,
    getLatestVersion,
    watchVersionUpdate,
    waitForVersionSync,
    args: {
      ipfs(name: string) {
        return getSubgraphApi(name).args.ipfs(name);
      },
      node(name: string) {
        return getSubgraphApi(name).args.node(name);
      },
      product(name: string) {
        return getSubgraphApi(name).args.product(name);
      }
    }
  };
};
