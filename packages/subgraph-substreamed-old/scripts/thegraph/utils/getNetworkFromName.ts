export const getNetworkFromName = (name: string): string => {
  const match = name.match(/^tellerv2-(.+)$/);
  if (!match) throw new Error(`Invalid subgraph name: ${name}`);
  return match[1];
};
