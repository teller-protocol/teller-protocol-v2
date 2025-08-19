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
  await runCmd(
    "json",
    ["-I", "-f", "package.json", "-e", `this.version = "${validVersion}"`],
    { disableEcho: true }
  );
  process.env.npm_package_version = validVersion;
};

export const getNextVersion = (releaseType: ReleaseType): string => {
  const latestVersion = new semver.SemVer(getPackageVersion());
  let nextVersion: semver.SemVer;
  switch (releaseType) {
    case "prepatch":
      nextVersion = latestVersion.inc("prepatch");
      break;

    case "preminor":
      nextVersion = latestVersion.inc("preminor");
      break;

    case "prerelease":
      nextVersion = latestVersion.inc("prerelease");
      break;

    case "release":
      nextVersion = latestVersion.inc("patch");
      break;

    case "missing": {
      const patchVersion = latestVersion.prerelease.length
        ? latestVersion.patch - 1
        : latestVersion.patch;
      nextVersion = new semver.SemVer(
        `${latestVersion.major}.${latestVersion.minor}.${patchVersion}-0`
      );
      break;
    }
  }
  return nextVersion.version;
};
