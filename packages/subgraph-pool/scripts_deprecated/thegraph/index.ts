import { Mutex } from "async-mutex";
import { MultiBar, SingleBar } from "cli-progress";
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

import {readConfigFile} from "./utils/config"
import path from "path";

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
  log: (msg = "") => progressBars.log(msg),
  error: (msg = "") => progressBars.log(msg)
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
          title: "None",
          value: "none",
          description: "Resyncing from the beginning."
        },
        {
          title: "Latest",
          value: "latest",
          description: "Fork from latest subgraph version (synced or not)."
        },
        {
          title: "Latest (synced ⏳)",
          value: "latest-synced",
          description:
            "Fork from latest, synced subgraph version. Will wait to fully sync before forking."
        }
      ]
    },
    // {
    //   name: "blockHandler",
    //   message: "Enable block handler?",
    //   type: prev => (prev === "none" ? null : "confirm")
    // },
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
  const releaseType: ReleaseType = answers.releaseType;
  let graftingType: GraftingType = answers.graftingType;
  // const blockHandler = answers.blockHandler ?? true;
  if (releaseType === "missing") {
    graftingType = "none";
  } else {
    subgraphs = answers.subgraphs;

    if (releaseType === "release") {
      graftingType = "latest-synced";
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
  releaseType: ReleaseType;
  graftingType: GraftingType;
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

  if (graftingType !== "latest-synced") {
    // make the next version a release if the previous one was missing
    const nextReleaseType =
      releaseType === "missing" ? "release" : "prerelease";

    void buildAndDeploySubgraphs({
      subgraphs: filteredSubgraphs,
      releaseType: nextReleaseType,
      graftingType: "latest-synced"
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
  let release = await mutex.acquire();
  const bar = progressBars.create(Infinity, 0, {
    name: subgraph.network,
    version: "v-",
    behind: Infinity
  });

  const args: BuildArgs = {
    subgraph,
    logger
  };
  if (graftingType.startsWith("latest")) {
    

   const latestVersion = await subgraph.api.getLatestVersion();
    //let latestVersion:any = "0.4.21-11" 
 

    if (latestVersion && graftingType === "latest-synced") {
      release();
      const updatedVersion = await waitForSync({
        subgraph,
        version: latestVersion,
        bar
      });
      Object.assign(latestVersion, updatedVersion);
      release = await mutex.acquire();
    }

    // if there is no latest version block number, wait and try again
    if (!latestVersion?.latestEthereumBlockNumber) {
      setTimeout(() => {
        void buildAndDeploy({
          subgraph,
          graftingType,
          nextVersion,
          logger
        });
      }, 5000);
      return;
    }

    const graftingBlock = latestVersion.latestEthereumBlockNumber;
   
      //override grafting base here 
 

    const grafting_config_data = await readConfigFile(  path.join(__dirname, 'api', 'config',  'grafting.json')  );
    console.log({grafting_config_data})

    //if (!grafting_config_data) {
    //throw new Error("no grafting config found ")
   // }


     let grafting_config_for_network = grafting_config_data["networks"][subgraph.network] ;

     console.log( subgraph.network )

     console.log({grafting_config_for_network})

      const USE_CUSTOM_GRAFTING = grafting_config_for_network.graft;

      if (USE_CUSTOM_GRAFTING) {
        args.grafting = {
          base: grafting_config_for_network.base,
          block: grafting_config_for_network.block

       };
      }else{
        args.grafting = {
          base: latestVersion.deploymentId,
          block: graftingBlock
        };
      }
      
      

      logger?.log(
          `Grafting subgraph: ${subgraph.name} (${subgraph.network}) at block ${args.grafting.block}`
      );
 

    if (latestVersion?.synced) {
      logger?.log(
        `Enabling block handler for ${subgraph.name} (${subgraph.network})`
      );

      args.block_handler = {
        block: subgraph.config.contracts.teller_v2.block
      };
    }
  }

  const buildId = await build(args);  
  try {
    await deploy({
      subgraph,
      newVersion: nextVersion,
      logger
    });
  } catch (err) {
    if (
      err instanceof Error &&
      !err.message.includes("HTTP error deploying the subgraph 504")
    ) {
      throw err;
    }
  }
  release();
  await new Promise(resolve => setTimeout(resolve, 10000));
  void subgraph.api.getLatestVersion().then(async latestVersion => {
    // TODO: there should always be a latest version
    if (!latestVersion) return;

    await waitForSync({ subgraph, version: latestVersion, bar });
  });
};
async function waitForSync({
  version,
  subgraph,
  bar
}: {
  version: SubgraphVersion;
  subgraph: ISubgraph;
  bar: SingleBar;
}): Promise<VersionUpdate> {
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
}

