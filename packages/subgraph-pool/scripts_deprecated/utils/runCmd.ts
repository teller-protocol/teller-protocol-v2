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
    const childProcess = spawn(cmd, args, { stdio: "pipe" });

    let output = "";

    const onData = (data: any, stream: NodeJS.WritableStream): void => {
      const str: string = data.toString();
      output += str;
      if (/Error:/i.test(str))
        return reject(`\n\n\n\nCommand: ${cmd} ${args.join(" ")}\n\n${output}`);
      opts?.onData?.(str);
      !opts?.disableEcho && stream.write(data);
    };
    childProcess.stdout.on("data", data => {
      onData(data, process.stdout);
    });
    childProcess.stderr.on("data", data => {
      onData(data, process.stderr);
    });
    childProcess.on("error", error => {
      reject(error);
    });
    childProcess.on("close", () => {
      resolve();
    });
  });
};
