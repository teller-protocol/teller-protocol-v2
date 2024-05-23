import { Logger } from "../../utils/logger";
import { runCmd } from "../../utils/runCmd";
import { updatePackageVersion } from "../../utils/version";
import { API, ISubgraph } from "../api";

import { create } from "./create";

interface DeployArgs {
  subgraph: ISubgraph;
  newVersion: string;
  logger?: Logger;
}
export const deploy = async (args: DeployArgs): Promise<void> => {
  const { subgraph, newVersion, logger } = args;

  await create({ subgraph });

  logger?.log(`Deploying subgraph: ${subgraph.name} ${subgraph.network}`);

  await subgraph.api.beforeDeploy?.();

  await runCmd(
    "yarn",
    [
      "graph",
      "deploy",
      "--version-label",
      newVersion,
      ...subgraph.api.args.node(),
      ...subgraph.api.args.ipfs(),
      ...subgraph.api.args.product(),
      subgraph.name
    ],
    { disableEcho: false }
  );
  await updatePackageVersion(newVersion);
};
