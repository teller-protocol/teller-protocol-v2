import { Logger } from "../../utils/logger";
import { runCmd } from "../../utils/runCmd";
import { API, ISubgraph } from "../api";
import { getNetworkConfig, setNetworkConfig } from "../utils/config";
import { getNetworkFromName } from "../utils/getNetworkFromName";

export interface BuildArgs {
  subgraph: ISubgraph;
  grafting?: {
    base: string;
    block: number | string;
  };
  block_handler?: {
    block: number | string;
  };
  logger?: Logger;
}
export const build = async (args: BuildArgs): Promise<string | undefined> => {
  const {
    subgraph,
    grafting,
    // eslint-disable-next-line @typescript-eslint/naming-convention
    block_handler,
    logger
  } = args;
  // const network = getNetworkFromName(name);

  logger?.log(`Building subgraph: ${subgraph.name} (${subgraph.network})`);

  const config = await getNetworkConfig(subgraph.network);

  if (grafting !== undefined) {
    config.grafting = {
      enabled: true,
      base: grafting.base,
      block: grafting.block
    };
  } else {
    config.grafting = {
      enabled: false
    };
  }

  if (block_handler !== undefined) {
      logger?.log(`Enabling block handler`);

    config.block_handler = {
      enabled: true,
      block: block_handler.block
    };
  } else {
    config.block_handler = {
      enabled: false
    };
  }

  await setNetworkConfig(subgraph.network, config);

  await runCmd(
    "yarn",
    [
      "workspace",
      "@teller-protocol/v2-contracts",

      "export",

      "--network",
      subgraph.network
    ],
    { disableEcho: true }
  );
  await runCmd(
    "yarn",
    [
      "hbs",

      "-D",
      `./config/${subgraph.network}.json`,

      "./src/subgraph.handlebars",

      "-o",
      ".",

      "-e",
      "yaml"
    ],
    { disableEcho: true }
  );
  await runCmd("yarn", ["graph", "codegen"], { disableEcho: true });
  return await new Promise<string | undefined>((resolve, reject) => {
    let buildId: string | undefined;
    void runCmd("yarn", ["graph", "build", ...subgraph.api.args.ipfs()], {
      disableEcho: true,
      onData: data => {
        const regex = /Build completed: (\w+)/;
        if (regex.test(data)) buildId = regex.exec(data)![1];
      }
    }).then(() => {
      if (buildId != null) {
        logger?.log(`Build ID: ${buildId}`);
      }
      resolve(buildId);
    });
  });
};
