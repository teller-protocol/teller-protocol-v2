import { Logger } from "../../utils/logger";
import { runCmd } from "../../utils/runCmd";
import { IApiArgs } from "../api";

interface AuthArgs {
  deployKey: string;
  apiArgs: IApiArgs;
  logger?: Logger;
}
export const auth = async (args: AuthArgs): Promise<void> => {
  const { deployKey, apiArgs } = args;

  await runCmd(
    "yarn",
    ["graph", "auth", ...apiArgs.node(), ...apiArgs.product(), deployKey],
    { disableEcho: true }
  );
};
