import * as semver from "semver";

import { ReleaseType } from "../thegraph/utils/types";

import { runCmd } from "./runCmd";

const getValidVersion = (version: string): string => {
  const validVersion = semver.valid(version);
  if (!validVersion) {
    throw new Error(`Invalid version: ${version}`);
  }
  return validVersion;
};

export const getPackageVersion = (): string => {
  const version = process.env.npm_package_version ?? "0.0.0";
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

export const getNextVersion = (releaseType: ReleaseType): string => {
  const latestVersion = getPackageVersion();
  let nextVersion: string | null;
  switch (releaseType) {
    case "patch":
      nextVersion = semver.inc(latestVersion, "prepatch");
      break;

    case "minor":
      nextVersion = semver.inc(latestVersion, "preminor");
      break;

    case "pre":
      nextVersion = semver.inc(latestVersion, "prerelease");
      break;

    case "release":
      nextVersion = semver.inc(latestVersion, "patch");
      break;

    case "missing":
      nextVersion = latestVersion;
      break;
  }
  if (!nextVersion) {
    throw new Error(`Invalid version: ${nextVersion}`);
  }
  return nextVersion;
};
