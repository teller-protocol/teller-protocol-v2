export type ReleaseType =
  | "prepatch"
  | "preminor"
  | "prerelease"
  | "release"
  | "missing";
export const isReleaseType = (_type: string): _type is ReleaseType => {
  return ["prepatch", "preminor", "prerelease", "release", "missing"].includes(
    _type
  );
};

export type GraftingType = "latest" | "latest-synced" | "none";
export const isGraftingType = (_type: string): _type is GraftingType => {
  return ["latest", "latest-synced", "none"].includes(_type);
};
