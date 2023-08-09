import { runCmd } from "../../utils/runCmd";
import { updatePackageVersion } from "../../utils/version";
import { API } from "../api";

import { create } from "./create";

interface DeployArgs {
  name: string;
  api: API;
  newVersion?: string;
}
export const deploy = async (args: DeployArgs): Promise<void> => {
  const { name, api, newVersion } = args;

  await create({ name, api });

  const versionLabel = `v${newVersion}`;

  console.log("Deploying subgraph:", name);
  console.log("Version label:", versionLabel);

  await runCmd(
    "yarn",
    [
      "graph",
      "deploy",
      "--version-label",
      versionLabel,
      ...api.args.node(name),
      ...api.args.ipfs(name),
      ...api.args.product(name),
      name
    ],
    { disableEcho: true }
  );
  await updatePackageVersion(versionLabel);
};
