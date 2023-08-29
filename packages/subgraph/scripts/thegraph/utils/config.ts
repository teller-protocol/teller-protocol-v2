import path from "path";

import { makeNodeDisklet } from "disklet";
import { makeMemlet } from "memlet";

const disklet = makeNodeDisklet("./config");
const memlet = makeMemlet(disklet);

export const listNetworks = async (): Promise<string[]> => {
  const files = await disklet.list(".");
  return Object.entries(files).reduce<string[]>((acc, [file, type]) => {
    if (type === "file" && file.endsWith(".json")) {
      const networkName = path.basename(file, ".json");
      acc.push(networkName);
    }
    return acc;
  }, []);
};

export const getNetworkConfig = (network: string): Promise<any> => {
  return memlet.getJson(`${network}.json`);
};

export const setNetworkConfig = async (
  network: string,
  config: any
): Promise<void> => {
  await memlet.setJson(`${network}.json`, config);
};
