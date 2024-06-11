

const fs = require('fs');
const path = require('path');

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
  product: "aws" | "studio" | "hosted" | "local";
  studio: {
    owner: string;
    network: string;
  };
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
    lender_commitment_staging: INetworkContractConfig;
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




 

export async function readConfigFile( file_path:any) : Promise<any> {

   
    try {
      // Construct the file path
   
     // console.log({configPath})
      // Check if the file exists
      const exists = await fileExists(file_path);
      if (exists) {
        // Read the JSON file
        const data = await readJSONFile(file_path);
        

        return data ; 
      } else {
        console.log('File not found');
      }
    } catch (err) {
      console.error('Error:', err);
    }
  
  }
  
  // Helper function to check if a file exists
  function fileExists(filePath:String) {
    return new Promise((resolve, reject) => {
      fs.access(filePath, fs.constants.F_OK, (err:any) => {
        if (err) {
          resolve(false);
        } else {
          resolve(true);
        }
      });
    });
  }
  
  // Helper function to read a JSON file
  function readJSONFile(filePath:String) {
    return new Promise((resolve, reject) => {
      fs.readFile(filePath, 'utf8', (err:any, data:any) => {
        if (err) {
          reject(err);
        } else {
          try {
            const jsonData = JSON.parse(data);
            resolve(jsonData);
          } catch (err) {
            reject(err);
          }
        }
      });
    });
  }