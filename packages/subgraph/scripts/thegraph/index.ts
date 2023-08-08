import { Mutex } from "async-mutex";

import { getNextVersion } from "../utils/version";

import { API, makeApi } from "./api";
import { build, BuildOpts, deploy } from "./commands";
import {
  GraftingType,
  isGraftingType,
  isReleaseType,
  ReleaseType
} from "./utils/types";

const mutex = new Mutex();

export const run = async (): Promise<void> => {
  const [releaseTypeArg] = process.argv.slice(-1);

  if (!releaseTypeArg) throw new Error("Missing release type");

  const [releaseType, graftingType] = releaseTypeArg.split(":");
  if (!isReleaseType(releaseType)) {
    throw new Error(`Invalid release type: ${releaseType}`);
  }
  if (!isGraftingType(graftingType)) {
    throw new Error(`Invalid grafting type: ${graftingType}`);
  }

  const api = await makeApi();
  await buildAndDeployAll({ api, releaseType, graftingType });
};
void run();

const buildAndDeployAll = async ({
  api,
  releaseType,
  graftingType
}: {
  api: API;
  releaseType: ReleaseType;
  graftingType: GraftingType;
}): Promise<void> => {
  const nextVersion = getNextVersion(releaseType);

  const subgraphs = await api.getSubgraphs();
  for (const name of subgraphs) {
    if (releaseType === "missing") {
      const latestVersion = await api.getLatestVersion(name);
      if (!!latestVersion) {
        console.log(`Subgraph ${name} is already deployed`);
        continue;
      }
    }
    await buildAndDeploy({
      name,
      api,
      nextVersion,
      graftingType
    });
  }
};

const buildAndDeploy = async ({
  name,
  api,
  nextVersion,
  graftingType
}: {
  name: string;
  api: API;
  nextVersion: string;
  graftingType: GraftingType;
}): Promise<void> => {
  const latestVersion = await api.getLatestVersion(name);
  // if (latestVersion?.label?.replace(/^v/, "") === nextVersion) {
  //   console.log(`Subgraph ${name} is already at version ${nextVersion}`);
  //   return;
  // }

  const opts: BuildOpts = {};
  if (graftingType === "latest") {
    if (latestVersion == null) {
      throw new Error(`Subgraph ${name} has no latest version`);
    } else {
      const update = await api.waitForVersionSync(name, latestVersion.id);
      Object.assign(latestVersion, update);
    }

    opts.grafting = {
      base: latestVersion.deploymentId,
      block: latestVersion.latestEthereumBlockNumber
    };
    opts.block_handler = {
      block: latestVersion.latestEthereumBlockNumber
    };
  }

  await mutex
    .runExclusive(async () => {
      const buildId = await build(name, opts);
      await deploy(name, nextVersion);
    })
    .then(() => {
      if (graftingType === "new") {
        void buildAndDeploy({
          name,
          api,
          nextVersion: getNextVersion("pre"),
          graftingType: "latest"
        });
      }
    });
};
