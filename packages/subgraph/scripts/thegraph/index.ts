import { Mutex } from "async-mutex";
import { MultiBar } from "cli-progress";
import prompts, { Choice } from "prompts";
import semver from "semver/preload";

import { Logger } from "../utils/logger";
import { getNextVersion, getPackageVersion } from "../utils/version";

import { ISubgraph, getSubgraphs, SubgraphVersion, VersionUpdate } from "./api";
import { build, BuildArgs, deploy } from "./commands";
import {
  GraftingType,
  isGraftingType,
  isReleaseType,
  ReleaseType
} from "./utils/types";

const mutex = new Mutex();

const progressBars = new MultiBar({
  format:
    "[{bar}] {name} @ {version} | Duration: {duration_formatted} ETA: {eta_formatted} | Blocks: {percentage}% {value}/{total} - behind: {behind}",

  barsize: 60,

  hideCursor: true,
  barCompleteChar: "\u2588",
  barIncompleteChar: "\u2591",
  stopOnComplete: true,

  // important! redraw everything to avoid "empty" completed bars
  forceRedraw: true
});
const previousLog = progressBars.log.bind(progressBars);
progressBars.log = (message: string) => previousLog(`${message}\n`);

const logger: Logger = {
  log: (msg: string) => progressBars.log(msg)
};

export const run = async (): Promise<void> => {
  let subgraphs = await getSubgraphs({
    logger
  });

  const packageVersion = getPackageVersion();
  const answers = await prompts([
    {
      name: "releaseType",
      message: `Select release type (Current version: v${packageVersion})`,
      type: "select",
      choices: () => {
        const choices: Choice[] = [];
        const addChoice = (value: ReleaseType, description?: string): number =>
          choices.push({
            title:
              value === "missing"
                ? `missing (only undeployed versions: v${getNextVersion(
                    "missing"
                  )})`
                : `${value} (bump to v${getNextVersion(value)})`,
            value,
            description
          });
        if (semver.prerelease(packageVersion)) {
          addChoice("prerelease");
          addChoice("release", "Fork latest release and enable block handler");
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
        ["missing", "release"].includes(answers.releaseType) ? null : "select",
      choices: [
        {
          title: "Latest",
          value: "latest",
          description: "Fork latest version"
        },
        {
          title: "None",
          value: "none",
          description: "Resync from the beginning"
        }
      ]
    },
    {
      name: "subgraphs",
      message: "Select subgraphs to deploy",
      type: (_, answers) =>
        answers.releaseType === "missing" ? null : "multiselect",
      choices: subgraphs.map(
        (subgraph): Choice => ({
          title: subgraph.network,
          value: subgraph
        })
      ),
      min: 1
    }
  ]);
  const releaseType = answers.releaseType;
  let graftingType = answers.graftingType;
  if (releaseType === "missing") {
    graftingType = "none";
  } else {
    subgraphs = answers.subgraphs;

    if (releaseType === "release") {
      graftingType = "latest-block-handler";
    }
  }

  if (!subgraphs || !releaseType || !graftingType)
    throw new Error("Missing data to deploy");

  await buildAndDeploySubgraphs({
    subgraphs,
    releaseType,
    graftingType
  });
};
void run();

const buildAndDeploySubgraphs = async ({
  subgraphs,
  releaseType,
  graftingType
}: {
  subgraphs: ISubgraph[];
  releaseType: string;
  graftingType: string;
}): Promise<void> => {
  if (!isReleaseType(releaseType)) {
    throw new Error(`Invalid release type: ${releaseType}`);
  }
  if (!isGraftingType(graftingType)) {
    throw new Error(`Invalid grafting type: ${graftingType}`);
  }

  const nextVersion = `v${getNextVersion(releaseType)}`;

  const filteredSubgraphs = new Array<ISubgraph>();
  await Promise.all(
    subgraphs.map(async subgraph => {
      if (releaseType === "missing") {
        const latestVersion = await subgraph.api.getLatestVersion();
        if (!!latestVersion) {
          progressBars.log(`Subgraph ${subgraph.name} is already deployed`);
          return;
        }
      }
      // only add subgraph if it is not already deployed
      filteredSubgraphs.push(subgraph);

      await buildAndDeploy({
        subgraph,
        graftingType,
        nextVersion,
        logger
      });
    })
  );

  return;
  if (graftingType !== "latest-block-handler") {
    // make the next version a release if the previous one was missing
    const nextReleaseType =
      releaseType === "missing" ? "release" : "prerelease";

    void buildAndDeploySubgraphs({
      subgraphs: filteredSubgraphs,
      releaseType: nextReleaseType,
      graftingType: "latest-block-handler"
    });
  }
};

const buildAndDeploy = async ({
  subgraph,
  graftingType,
  nextVersion,
  logger
}: {
  subgraph: ISubgraph;
  graftingType: GraftingType;
  nextVersion: string;
  logger?: Logger;
}): Promise<void> => {
  const bar = progressBars.create(Infinity, 0, {
    name: subgraph.network,
    version: "v-",
    behind: Infinity
  });

  const waitForSync = async (
    version: SubgraphVersion
  ): Promise<VersionUpdate> => {
    const total = version.totalEthereumBlocksCount ?? 0;
    const value = version.latestEthereumBlockNumber ?? 0;
    bar.start(total, value, {
      name: subgraph.network,
      version: version.label ?? "",
      behind: total - value
    });
    return await subgraph.api.waitForVersionSync(version.id, updated => {
      bar.setTotal(updated.totalEthereumBlocksCount);

      const value = updated.synced
        ? bar.getTotal()
        : updated.latestEthereumBlockNumber;
      bar.update(value, {
        name: subgraph.network,
        version: version.label ?? "",
        behind:
          updated.totalEthereumBlocksCount - updated.latestEthereumBlockNumber
      });
    });
  };

  const args: BuildArgs = {
    subgraph,
    logger
  };
  if (graftingType.startsWith("latest")) {
    const latestVersion = await subgraph.api.getLatestVersion();
    if (latestVersion == null) {
      throw new Error(`Subgraph ${subgraph.name} has no latest version`);
    }

    const updatedVersion = await waitForSync(latestVersion);
    const blockNumber = updatedVersion.latestEthereumBlockNumber;
    if (blockNumber == null) {
      throw new Error(`Subgraph ${subgraph.name} has no latest block number`);
    }

    args.grafting = {
      base: latestVersion.deploymentId,
      block: blockNumber
    };
  }
  args.block_handler = {
    block: subgraph.config.contracts.teller_v2.block
  };

  await mutex.runExclusive(async () => {
    const buildId = await build(args);
    await deploy({
      subgraph,
      newVersion: nextVersion,
      logger
    });
  });
};
