import * as semver from "semver";

import { runCmd } from "./runCmd";

const getValidVersion = (version: string): string => {
  const validVersion = semver.valid(version);
  if (!validVersion) {
    throw new Error(`Invalid version: ${version}`);
  }
  return validVersion;
};

export const getPackageVersion = (): string => {
  const version = process.env.npm_package_version || "0.0.0";
  return getValidVersion(version);
};

export const updatePackageVersion = async (version: string): Promise<void> => {
  const validVersion = getValidVersion(version);
  await runCmd("json", [
    "-I",
    "-f",
    "package.json",
    "-e",
    `this.version = "${validVersion}"`
  ]);
  process.env.npm_package_version = validVersion;
};

export const getNextVersion = (
  releaseType: "patch" | "minor" | "pre" | "release"
): string => {
  const latestVersion = getPackageVersion();
  switch (releaseType) {
    case "patch":
      return semver.inc(latestVersion, "prepatch");

    case "minor":
      return semver.inc(latestVersion, "preminor");

    case "pre":
      return semver.inc(latestVersion, "prerelease");

    case "release":
      return semver.inc(latestVersion, "patch");

    default:
      throw new Error(`Unknown type: ${releaseType}`);
  }
};
