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
  const latestVersion = getPackageVersion();
  let nextVersion: string | undefined | null;
  switch (releaseType) {
    case "prepatch":
      nextVersion = semver.inc(latestVersion, "prepatch");
      break;

    case "preminor":
      nextVersion = semver.inc(latestVersion, "preminor");
      break;

    case "prerelease":
      nextVersion = semver.inc(latestVersion, "prerelease");
      break;

    case "release":
      nextVersion = semver.inc(latestVersion, "patch");
      break;

    case "missing": {
      const prereleaseValues = semver.prerelease(latestVersion);
      let prereleaseVersion = 0;
      if (prereleaseValues != null) {
        prereleaseVersion = Number(prereleaseValues.slice(-1)[0]);
        if (isNaN(prereleaseVersion)) {
          prereleaseVersion = 0;
        }
        if (prereleaseVersion > 0) {
          prereleaseVersion -= 1;
        }
      }
      nextVersion = semver.coerce(latestVersion)?.version;
      if (nextVersion != null) {
        nextVersion = `${nextVersion}-${prereleaseVersion}`;
      }
      break;
    }
  }
  if (!nextVersion) {
    throw new Error(`Invalid version: ${nextVersion}`);
  }
  return nextVersion;
};
