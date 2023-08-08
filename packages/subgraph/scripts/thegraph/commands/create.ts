import { runCmd } from "../../utils/runCmd";
import { getNetworkFromName } from "../utils/getNetworkFromName";

import { getNodeArgsFromNetwork } from "./args";

export const create = async (name: string): Promise<void> => {
  const network = getNetworkFromName(name);
  await runCmd("yarn", [
    "graph",
    "create",
    ...getNodeArgsFromNetwork(network),
    name
  ]);
};
