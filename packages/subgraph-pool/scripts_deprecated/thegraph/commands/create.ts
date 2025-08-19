import { Logger } from "../../utils/logger";
import { runCmd } from "../../utils/runCmd";
import { API, ISubgraph } from "../api";

interface CreateArgs {
  subgraph: ISubgraph;
  logger?: Logger;
}
export const create = async (args: CreateArgs): Promise<void> => {
  const { subgraph } = args;
  const nodeArgs = subgraph.api.args.node();
  // If there are no node args, then we don't need to create the subgraph
  if (nodeArgs.length === 0) return;
  await runCmd("yarn", ["graph", "create", ...nodeArgs, subgraph.name], {
    disableEcho: true
  });
};
