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

export interface INetworkConfig {
  enabled: boolean;
  name: string;
  network: string;
  export_network_name: string;
  product: "aws" | "studio";
  grafting:
    | {
        enabled: true;
        base: string;
        block: string | number;
      }
    | {
        enabled: false;
      };
  block_handler:
    | {
        enabled: true;
        block: string | number;
      }
    | {
        enabled: false;
      };
  contracts: {
    teller_v2: INetworkContractConfig;
    market_registry: INetworkContractConfig;
    lender_commitment: INetworkContractConfig;
    collateral_manager: INetworkContractConfig;
    lender_manager: INetworkContractConfig;
    market_liquidity_rewards: INetworkContractConfig;
  };
}
interface INetworkContractConfig {
  enabled: boolean;
  address: string;
  block: string;
}

export const getNetworkConfig = (network: string): Promise<INetworkConfig> => {
  return memlet.getJson(`${network}.json`);
};

export const setNetworkConfig = async (
  network: string,
  config: INetworkConfig
): Promise<void> => {
  await memlet.setJson(`${network}.json`, config);
};
