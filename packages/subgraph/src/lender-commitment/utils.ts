import { dataSource } from "@graphprotocol/graph-ts";

export enum CommitmentStatus {
  Active,
  Expired,
  Deleted,
  Drained,
  Inactive
}

const CommitmentStatusValues = new Array<string>(10);
CommitmentStatusValues[CommitmentStatus.Active] = "Active";
CommitmentStatusValues[CommitmentStatus.Expired] = "Expired";
CommitmentStatusValues[CommitmentStatus.Deleted] = "Deleted";
CommitmentStatusValues[CommitmentStatus.Drained] = "Drained";
CommitmentStatusValues[CommitmentStatus.Inactive] = "Inactive";

export function commitmentStatusToEnum(status: string): CommitmentStatus {
  return CommitmentStatusValues.indexOf(status);
}

export function commitmentStatusToString(status: CommitmentStatus): string {
  return CommitmentStatusValues[status];
}

export function isRolloverable(): boolean {
  const ctx = dataSource.context();
  return !!ctx.isSet("isRolloverable") && ctx.getBoolean("isRolloverable");
}