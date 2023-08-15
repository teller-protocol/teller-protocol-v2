import { makeNodeDisklet } from "disklet";
import { makeMemlet } from "memlet";

const disklet = makeNodeDisklet("./config");
const memlet = makeMemlet(disklet);

export const getConfig = (network: string): Promise<any> => {
  return memlet.getJson(`${network}.json`);
};

export const setConfig = async (
  network: string,
  config: any
): Promise<void> => {
  await memlet.setJson(`${network}.json`, config);
};
