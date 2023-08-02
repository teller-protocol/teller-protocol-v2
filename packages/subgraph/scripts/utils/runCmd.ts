import { spawn } from "child_process";

export const runCmd = (cmd: string, args: string[]): Promise<void> => {
  return new Promise((resolve, reject) => {
    const build = spawn(cmd, args, { stdio: "pipe" });
    build.stdout.on("data", data => console.log(data.toString()));
    build.on("error", error => {
      reject(error);
    });
    build.on("close", () => {
      resolve();
    });
  });
};
