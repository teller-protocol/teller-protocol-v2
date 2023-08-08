import { Mutex } from "async-mutex";
import prompts, { Choice } from "prompts";
import semver from "semver/preload";

import { getNextVersion, getPackageVersion } from "../utils/version";

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
  const api = await makeApi();
  const subgraphs: string[] | undefined = await api.getSubgraphs();
  let releaseType: ReleaseType | undefined;
  let graftingType: GraftingType | undefined;

  const packageVersion = getPackageVersion();
  const answers = await prompts([
    {
      name: "releaseType",
      message: `Select release type (Current version: v${packageVersion})`,
      type: "select",
      choices: () => {
        const choices: Choice[] = [];
        const addChoice = (value: ReleaseType): number =>
          choices.push({
            title:
              value === "missing"
                ? `missing (only undeployed versions: v${getNextVersion(
                    "missing"
                  )})`
                : `${value} (bump to v${getNextVersion(value)})`,
            value
          });
        if (semver.prerelease(packageVersion)) {
          addChoice("prerelease");
          addChoice("release");
        } else {
          addChoice("prepatch");
          addChoice("preminor");
        }
        addChoice("missing");
        return choices;
      }
    },
    {
      name: "graftingType",
      message: "Select grafting type",
      type: (_, answers) =>
        answers.releaseType === "missing" ? null : "select",
      choices: [
        { title: "Latest", value: "latest" },
        { title: "None", value: "none" }
      ]
    },
    {
      name: "subgraphs",
      message: "Select subgraphs to deploy",
      type: (_, answers) =>
        answers.releaseType === "missing" ? null : "multiselect",
      choices: subgraphs.map(
        (name): Choice => ({
          title: name.replace(/tellerv2-(.+)/, (_, $1: string) =>
            $1
              .replace("-", " ")
              .replace(/\b[a-z](?=[a-z])/g, letter => letter.toUpperCase())
          ),
          value: name
        })
      )
    }
  ]);
  if (answers.releaseType === "missing") {
    releaseType = "missing";
    graftingType = "none";
  }

  if (!subgraphs || !releaseType || !graftingType)
    throw new Error("Missing data to deploy");

  await buildAndDeploySubgraphs({
    api,
    subgraphs,
    releaseType,
    graftingType
  });
};
void run();

const buildAndDeploySubgraphs = async ({
  api,
  subgraphs,
  releaseType,
  graftingType
}: {
  api: API;
  subgraphs: string[];
  releaseType: string;
  graftingType: string;
}): Promise<void> => {
  if (!isReleaseType(releaseType)) {
    throw new Error(`Invalid release type: ${releaseType}`);
  }
  if (!isGraftingType(graftingType)) {
    throw new Error(`Invalid grafting type: ${graftingType}`);
  }

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
      releaseType,
      graftingType
    });
  }
};

const buildAndDeploy = async ({
  name,
  api,
  releaseType,
  graftingType
}: {
  name: string;
  api: API;
  releaseType: ReleaseType;
  graftingType: GraftingType;
}): Promise<void> => {
  const latestVersion = await api.getLatestVersion(name);
  // if (latestVersion?.label?.replace(/^v/, "") === nextVersion) {
  //   console.log(`Subgraph ${name} is already at version ${nextVersion}`);
  //   return;
  // }
  const nextVersion = getNextVersion(releaseType);

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
      if (graftingType === "none") {
        void buildAndDeploy({
          name,
          api,
          // make the next version a release if the previous one was missing
          releaseType: releaseType === "missing" ? "release" : "prerelease",
          graftingType: "latest"
        });
      }
    });
};
