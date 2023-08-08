export const getNodeArgsFromNetwork = (network: string): string[] => {
  switch (network) {
    case "mantle":
      throw new Error("Mantle Mainnet is not supported");

    case "mantle-testnet":
      return ["--node", "https://graph.testnet.mantle.xyz/deploy"];

    default:
      return [];
  }
};

export const getIpfsArgsFromNetwork = (network: string): string[] => {
  switch (network) {
    case "mantle":
      throw new Error("Mantle Mainnet is not supported");

    case "mantle-testnet":
      return ["--ipfs", "https://ipfs.testnet.mantle.xyz/"];

    default:
      return ["--ipfs", "https://api.thegraph.com/ipfs/api/v0"];
  }
};

export const getProductArgsFromNetwork = (network: string): string[] => {
  switch (network) {
    case "mainnet":
    case "polygon":
    case "arbitrum":
    case "goerli":
      return ["--product", "subgraph-studio"];

    default:
      return [];
  }
};
