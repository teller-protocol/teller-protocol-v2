import { makeMantle } from "./mantle";
import { makeStudio } from "./studio";

export interface SubgraphVersion {
  id: number;
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

export interface API {
  getSubgraphs: () => Promise<string[]>;
  getLatestVersion: (
    name: string
  ) => Promise<SubgraphVersion | null | undefined>;
  watchVersionUpdate: (
    name: string,
    versionId: number,
    cb: (
      version: VersionUpdate,
      unsubscribe: () => void
    ) => Promise<void> | void
  ) => void;
  waitForVersionSync: (
    name: string,
    versionId: number
  ) => Promise<VersionUpdate>;
}

export const makeApi = async (): Promise<API> => {
  const studio = await makeStudio();
  const aws = await makeMantle();

  const nameMap = new Map<string, API>();
  const getSubgraphApi = (name: string): API => {
    const api = nameMap.get(name);
    if (!api) throw new Error(`API for ${name} does not exist`);
    return api;
  };
  const mapSubgraphApis = async (api: API): Promise<string[]> => {
    const names = await api.getSubgraphs();
    for (const name of names) {
      if (nameMap.has(name)) {
        throw new Error(`API for ${name} already exists`);
      }
      nameMap.set(name, api);
    }
    return names;
  };

  return {
    getSubgraphs(): Promise<string[]> {
      return Promise.all([
        mapSubgraphApis(studio),
        mapSubgraphApis(aws)
      ]).then(s => s.flat());
    },
    getLatestVersion(
      name: string
    ): Promise<SubgraphVersion | null | undefined> {
      const api = getSubgraphApi(name);
      return api.getLatestVersion(name);
    },
    waitForVersionSync(
      name: string,
      versionId: number
    ): Promise<VersionUpdate> {
      const api = getSubgraphApi(name);
      return api.waitForVersionSync(name, versionId);
    },
    watchVersionUpdate(
      name: string,
      versionId: number,
      cb: (
        version: VersionUpdate,
        unsubscribe: () => void
      ) => Promise<void> | void
    ): void {
      const api = getSubgraphApi(name);
      api.watchVersionUpdate(name, versionId, cb);
    }
  };
};
