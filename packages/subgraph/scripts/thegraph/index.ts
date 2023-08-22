import { Mutex } from "async-mutex";
import { MultiBar } from "cli-progress";
import prompts, { Choice } from "prompts";
import semver from "semver/preload";

import { Logger } from "../utils/logger";
import { getNextVersion, getPackageVersion } from "../utils/version";

import { API, makeApi, SubgraphVersion, VersionUpdate } from "./api";
import { build, BuildArgs, deploy } from "./commands";
import {
  GraftingType,
  isGraftingType,
  isReleaseType,
  ReleaseType
} from "./utils/types";
import * as websocket from "./ws";

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
  const api = await makeApi({
    logger
  });
  let subgraphs: string[] = await api.getSubgraphs();

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
          description:
            "Double deployment (1st: NO block handler, 2nd: WITH block handler)"
        },
        {
          title: "Latest + Block Handler",
          value: "latest-block-handler",
          description: "Single deployment"
        },
        {
          title: "Latest + Wait for Sync",
          value: "latest-synced",
          description:
            "Single deployment that waits for the latest deployed subgraph to sync"
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
        (name): Choice => ({
          title: name.replace(/tellerv2-(.+)/, (_, $1: string) =>
            $1
              .replace("-", " ")
              .replace(/\b[a-z](?=[a-z])/g, letter => letter.toUpperCase())
          ),
          value: name
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

  const nextVersion = `v${getNextVersion(releaseType)}`;

  const filteredSubgraphs = new Array<string>();
  await Promise.all(
    subgraphs.map(async name => {
      if (releaseType === "missing") {
        const latestVersion = await api.getLatestVersion(name);
        if (!!latestVersion) {
          progressBars.log(`Subgraph ${name} is already deployed`);
          return;
        }
      }
      // only add subgraph if it is not already deployed
      filteredSubgraphs.push(name);

      await buildAndDeploy({
        name,
        api,
        graftingType,
        nextVersion,
        logger
      });
    })
  );

  if (graftingType !== "latest-block-handler") {
    // make the next version a release if the previous one was missing
    const nextReleaseType =
      releaseType === "missing" ? "release" : "prerelease";

    void buildAndDeploySubgraphs({
      api,
      subgraphs,
      releaseType: nextReleaseType,
      graftingType: "latest-block-handler"
    });
  }
};

const buildAndDeploy = async ({
  name,
  api,
  graftingType,
  nextVersion,
  logger
}: {
  name: string;
  api: API;
  graftingType: GraftingType;
  nextVersion: string;
  logger?: Logger;
}): Promise<void> => {
  const bar = progressBars.create(Infinity, 0, {
    name,
    version: "v-",
    behind: Infinity
  });

  const waitForSync = async (
    version: SubgraphVersion
  ): Promise<VersionUpdate> => {
    bar.start(
      version.totalEthereumBlocksCount,
      version.latestEthereumBlockNumber,
      {
        name,
        version: version.label ?? "",
        behind:
          version.totalEthereumBlocksCount - version.latestEthereumBlockNumber
      }
    );
    return await api.waitForVersionSync(name, version.id, updated => {
      bar.setTotal(updated.totalEthereumBlocksCount);

      const value = updated.synced
        ? bar.getTotal()
        : updated.latestEthereumBlockNumber;
      bar.update(value, {
        name,
        version: version.label ?? "",
        behind:
          updated.totalEthereumBlocksCount - updated.latestEthereumBlockNumber
      });
    });
  };

  const args: BuildArgs = {
    name,
    api,
    logger
  };
  if (graftingType.startsWith("latest")) {
    const latestVersion = await api.getLatestVersion(name);
    if (latestVersion == null) {
      throw new Error(`Subgraph ${name} has no latest version`);
    }
    let blockNumber = latestVersion.latestEthereumBlockNumber;

    if (graftingType === "latest-synced") {
      const updatedVersion = await waitForSync(latestVersion);
      blockNumber = updatedVersion.latestEthereumBlockNumber;
    }

    args.grafting = {
      base: latestVersion.deploymentId,
      block: blockNumber
    };
    if (graftingType === "latest-block-handler") {
      args.block_handler = {
        block: blockNumber
      };
    }
  }

  await mutex
    .runExclusive(async () => {
      const buildId = await build(args);
      await deploy({ name, api, newVersion: nextVersion, logger });
    })
    .then(() => {
      void api.getLatestVersion(name).then(latestVersion => {
        // TODO: there should always be a latest version
        if (!latestVersion) return;

        void waitForSync(latestVersion);
      });
    });
};
