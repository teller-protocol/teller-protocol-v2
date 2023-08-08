export type ReleaseType =
  | "prepatch"
  | "preminor"
  | "prerelease"
  | "release"
  | "missing";
export const isReleaseType = (_type: string): _type is ReleaseType => {
  return ["patch", "minor", "pre", "release", "missing"].includes(_type);
};

export type GraftingType = "latest" | "none";
export const isGraftingType = (_type: string): _type is GraftingType => {
  return ["latest", "none"].includes(_type);
};
