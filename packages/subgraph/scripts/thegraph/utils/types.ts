export type ReleaseType = "patch" | "minor" | "pre" | "release" | "missing";
export const isReleaseType = (_type: string): _type is ReleaseType => {
  return ["patch", "minor", "pre", "release", "none"].includes(_type);
};

export type GraftingType = "latest" | "new";
export const isGraftingType = (_type: string): _type is GraftingType => {
  return ["latest", "new"].includes(_type);
};
