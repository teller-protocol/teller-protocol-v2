import { runCmd } from "../../utils/runCmd";
import { getConfig, setConfig } from "../utils/config";
import { getNetworkFromName } from "../utils/getNetworkFromName";

import { getIpfsArgsFromNetwork } from "./args";

export interface BuildOpts {
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
): Promise<string | undefined> => {
  const network = getNetworkFromName(name);

  console.log("Building subgraph:", name);
  console.log();

  const config = await getConfig(network);

  if (opts.grafting !== undefined) {
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

  if (opts.block_handler !== undefined) {
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

  await setConfig(network, config);

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
  await runCmd("yarn", ["graph", "codegen"], { disableEcho: true });
  return await new Promise<string | undefined>((resolve, reject) => {
    let buildId: string | undefined;
    void runCmd(
      "yarn",
      ["graph", "build", ...getIpfsArgsFromNetwork(network)],
      {
        disableEcho: true,
        onData: data => {
          const regex = /Build completed: (\w+)/;
          if (regex.test(data)) buildId = regex.exec(data)![1];
        }
      }
    ).then(() => {
      if (buildId != null) {
        console.log("Build ID:", buildId);
      }
      resolve(buildId);
    });
  });
};
