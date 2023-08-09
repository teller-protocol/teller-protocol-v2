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

export interface InnerAPI {
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

  args: {
    ipfs: (name: string) => string[];
    node: (name: string) => string[];
    product: (name: string) => string[];
  };
}
export interface API extends InnerAPI {
  waitForVersionSync: (
    name: string,
    versionId: number
  ) => Promise<VersionUpdate>;
}

export const makeApi = async (): Promise<API> => {
  const studio = await makeStudio();
  const aws = await makeMantle();

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
    name: string
  ): Promise<SubgraphVersion | null | undefined> => {
    const api = getSubgraphApi(name);
    return api.getLatestVersion(name);
  };

  const watchVersionUpdate = (
    name: string,
    versionId: number,
    cb: (
      version: VersionUpdate,
      unsubscribe: () => void
    ) => Promise<void> | void
  ): void => {
    const api = getSubgraphApi(name);
    api.watchVersionUpdate(name, versionId, cb);
  };

  const waitForVersionSync = (
    name: string,
    versionId: number
  ): Promise<VersionUpdate> => {
    return new Promise((resolve, reject) => {
      // start a timer to track how long it took to sync deployment
      const timerLabel = `${name} sync time`;
      console.time(timerLabel);
      watchVersionUpdate(name, versionId, (version, unsubscribe) => {
        const syncedPercent = (
          (version.latestEthereumBlockNumber /
            version.totalEthereumBlocksCount) *
          100
        ).toFixed(2);

        console.log();
        console.log(
          `${name}: ${syncedPercent}% synced \n` +
            `\t* latest block: ${version.latestEthereumBlockNumber} \n` +
            `\t* total blocks: ${version.totalEthereumBlocksCount}\n`
        );

        if (version.failed) {
          unsubscribe();
          reject(`Version "${versionId} failed`);
        } else if (version.synced) {
          console.timeEnd(timerLabel);
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
