import { Mutex } from "async-mutex";
import { makeNodeDisklet } from "disklet";
import { makeMemlet, Memlet } from "memlet";

import { runCmd } from "../utils/runCmd";
import { getNextVersion, updatePackageVersion } from "../utils/version";

import { makeStudio } from "./api";

const mutex = new Mutex();

const getMemlet = (): Memlet => {
  const disklet = makeNodeDisklet("./config");
  const memlet = makeMemlet(disklet);
  return memlet;
};

interface BuildOpts {
  grafting?: {
    base: string;
    block: number;
  };
  block_handler?: {
    block: number;
  };
}
export const build = async (
  name: string,
  opts: BuildOpts = {}
): Promise<void> => {
  const network = name.split("-")[1].toLowerCase();

  console.log("Building subgraph:", name);
  console.log();

  const memlet = getMemlet();

  const config = await memlet.getJson(`${network}.json`);

  if ("grafting" in opts) {
    config.grafting = {
      enabled: true,
      base: opts.grafting.base,
      block: opts.grafting.block
    };
  } else {
    config.grafting = {
      enabled: false
    };
  }
  console.log("Grafting:", JSON.stringify(config.grafting, null, 2));

  if ("block_handler" in opts) {
    config.block_handler = {
      enabled: true,
      block: opts.block_handler.block
    };
  } else {
    config.block_handler = {
      enabled: false
    };
  }
  console.log("Block Handler:", JSON.stringify(config.block_handler, null, 2));

  await memlet.setJson(`${network}.json`, config);

  await runCmd("yarn", [
    "workspace",
    "@teller-protocol/v2-contracts",

    "export",

    "--network",
    network
  ]);
  await runCmd("yarn", [
    "hbs",

    "-D",
    `./config/${network}.json`,

    "./src/subgraph.handlebars",

    "-o",
    ".",

    "-e",
    "yaml"
  ]);
  await runCmd("yarn", ["graph", "codegen"]);
  await runCmd("yarn", ["graph", "build"]);
};

export const deploy = async (
  name: string,
  newVersion = "0.0.1"
): Promise<void> => {
  const network = name.split("-")[1].toLowerCase();
  const versionLabel = `v${newVersion}`;

  console.log("Deploying subgraph:", name);
  console.log("Version label:", versionLabel);

  const args: string[] = [
    "graph",
    "deploy",
    name,
    "--version-label",
    versionLabel
  ];

  switch (network) {
    case "mantle":
      args.push("--node", "https://");
      break;

    default:
      args.push("--product", "subgraph-studio");
  }

  await runCmd("yarn", args);
  await updatePackageVersion(versionLabel);
};

export const run = async (): Promise<void> => {
  const [releaseTypeArg] = process.argv.slice(-1);

  if (!releaseTypeArg) throw new Error("Missing release type");

  const [releaseType, graftingType] = releaseTypeArg.split(":");

  const studio = await makeStudio();
  await buildAndDeployAll(
    studio,
    releaseType as ReleaseType,
    graftingType as GraftingType
  );
};
void run();

type AwaitedReturnType<T extends (...args: any) => any> = ReturnType<
  T
> extends Promise<infer U>
  ? U
  : never;

type ReleaseType = "patch" | "minor" | "pre" | "release";
const isReleaseType = (_type: string): _type is ReleaseType => {
  return ["patch", "minor", "pre", "release"].includes(_type);
};

type GraftingType = "latest" | "new";
const isGraftingType = (_type: string): _type is GraftingType => {
  return ["latest", "new"].includes(_type);
};

const buildAndDeployAll = async (
  studio: AwaitedReturnType<typeof makeStudio>,
  releaseType: ReleaseType,
  graftingType: GraftingType
): Promise<void> => {
  if (!isReleaseType(releaseType)) {
    throw new Error(`Invalid release type: ${releaseType}`);
  }
  if (!isGraftingType(graftingType)) {
    throw new Error(`Invalid grafting type: ${graftingType}`);
  }

  const nextVersion = getNextVersion(releaseType);

  const subgraphs = await studio.getUserSubgraphs();
  for (const subgraph of subgraphs) {
    await buildAndDeploy({
      name: subgraph.name,
      studio,
      nextVersion,
      graftingType
    });
  }
};

const buildAndDeploy = async ({
  name,
  studio,
  nextVersion,
  graftingType
}: {
  name: string;
  studio: AwaitedReturnType<typeof makeStudio>;
  nextVersion: string;
  graftingType: GraftingType;
}): Promise<void> => {
  const latestVersion = await studio.getLatestVersion(name);

  const opts: BuildOpts = {};
  if (graftingType === "latest") {
    if (latestVersion == null) {
      throw new Error(`Subgraph ${name} has no latest version`);
    } else {
      const update = await studio.waitForVersionSync(latestVersion.id);
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
      await build(name, opts);
      await deploy(name, nextVersion);
    })
    .then(() => {
      if (graftingType === "new") {
        void buildAndDeploy({
          name,
          studio,
          nextVersion: getNextVersion("pre"),
          graftingType: "latest"
        });
      }
    });
};
