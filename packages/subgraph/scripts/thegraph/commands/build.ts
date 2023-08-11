import { Logger } from "../../utils/logger";
import { runCmd } from "../../utils/runCmd";
import { API } from "../api";
import { getConfig, setConfig } from "../utils/config";
import { getNetworkFromName } from "../utils/getNetworkFromName";

export interface BuildArgs {
  name: string;
  api: API;
  grafting?: {
    base: string;
    block: number;
  };
  block_handler?: {
    block: number;
  };
  logger?: Logger;
}
export const build = async (args: BuildArgs): Promise<string | undefined> => {
  const {
    name,
    api,
    grafting,
    // eslint-disable-next-line @typescript-eslint/naming-convention
    block_handler,
    logger
  } = args;
  const network = getNetworkFromName(name);

  logger?.log(`Building subgraph: ${name}`);

  const config = await getConfig(network);

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
    config.block_handler = {
      enabled: true,
      block: block_handler.block
    };
  } else {
    config.block_handler = {
      enabled: false
    };
  }

  await setConfig(network, config);

  await runCmd(
    "yarn",
    [
      "workspace",
      "@teller-protocol/v2-contracts",

      "export",

      "--network",
      network
    ],
    { disableEcho: true }
  );
  await runCmd(
    "yarn",
    [
      "hbs",

      "-D",
      `./config/${network}.json`,

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
    void runCmd("yarn", ["graph", "build", ...api.args.ipfs(name)], {
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
