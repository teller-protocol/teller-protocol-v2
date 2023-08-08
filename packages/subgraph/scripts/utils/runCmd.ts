import { spawn } from "child_process";

interface RunCmdOptions {
  onData?: (data: string) => void;
  disableEcho?: boolean;
}
export const runCmd = (
  cmd: string,
  args: string[],
  opts?: RunCmdOptions
): Promise<void> => {
  return new Promise((resolve, reject) => {
    const build = spawn(cmd, args, { stdio: "pipe" });
    build.stdout.on("data", data => {
      opts?.onData?.(data.toString());
      !opts?.disableEcho && process.stdout.write(data);
    });
    build.stderr.on("data", data => {
      opts?.onData?.(data.toString());
      !opts?.disableEcho && process.stderr.write(data);
    });
    build.on("error", error => {
      reject(error);
    });
    build.on("close", () => {
      resolve();
    });
  });
};
