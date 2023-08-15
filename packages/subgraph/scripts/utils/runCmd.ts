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
    const onData = (data: any, stream: NodeJS.WritableStream): void => {
      const str = data.toString();
      if (str.includes("Error:")) return reject(`\n${str}`);
      opts?.onData?.(str);
      !opts?.disableEcho && stream.write(data);
    };
    build.stdout.on("data", data => {
      onData(data, process.stdout);
    });
    build.stderr.on("data", data => {
      onData(data, process.stderr);
    });
    build.on("error", error => {
      reject(error);
    });
    build.on("close", () => {
      resolve();
    });
  });
};
