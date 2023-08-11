import { Logger } from "../../utils/logger";
import { runCmd } from "../../utils/runCmd";
import { updatePackageVersion } from "../../utils/version";
import { API } from "../api";

import { create } from "./create";

interface DeployArgs {
  name: string;
  api: API;
  newVersion: string;
  logger?: Logger;
}
export const deploy = async (args: DeployArgs): Promise<void> => {
  const { name, api, newVersion, logger } = args;

  await create({ name, api });

  logger?.log(`Deploying subgraph: ${name} ${newVersion}`);

  await runCmd(
    "yarn",
    [
      "graph",
      "deploy",
      "--version-label",
      newVersion,
      ...api.args.node(name),
      ...api.args.ipfs(name),
      ...api.args.product(name),
      name
    ],
    { disableEcho: true }
  );
  await updatePackageVersion(newVersion);
};
