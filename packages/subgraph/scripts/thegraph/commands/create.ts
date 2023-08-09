import { runCmd } from "../../utils/runCmd";
import { API } from "../api";

interface CreateArgs {
  name: string;
  api: API;
}
export const create = async (args: CreateArgs): Promise<void> => {
  const { name, api } = args;
  const nodeArgs = api.args.node(name);
  // If there are no node args, then we don't need to create the subgraph
  if (nodeArgs.length === 0) return;
  await runCmd("yarn", ["graph", "create", ...nodeArgs, name]);
};
