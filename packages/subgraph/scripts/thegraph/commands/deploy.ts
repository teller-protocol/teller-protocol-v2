import { runCmd } from "../../utils/runCmd";
import { updatePackageVersion } from "../../utils/version";
import { getNetworkFromName } from "../utils/getNetworkFromName";

import {
  getIpfsArgsFromNetwork,
  getNodeArgsFromNetwork,
  getProductArgsFromNetwork
} from "./args";
import { create } from "./create";

export const deploy = async (
  name: string,
  newVersion = "0.0.1"
): Promise<void> => {
  const network = getNetworkFromName(name);

  await create(name);

  const versionLabel = `v${newVersion}`;

  console.log("Deploying subgraph:", name);
  console.log("Version label:", versionLabel);

  const args: string[] = [
    "graph",
    "deploy",
    "--version-label",
    versionLabel,
    ...getNodeArgsFromNetwork(network),
    ...getIpfsArgsFromNetwork(network),
    ...getProductArgsFromNetwork(network),
    name
  ];

  await runCmd("yarn", args, { disableEcho: true });
  await updatePackageVersion(versionLabel);
};
