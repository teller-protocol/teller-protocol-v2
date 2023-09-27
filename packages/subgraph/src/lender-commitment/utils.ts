import { ByteArray, dataSource } from "@graphprotocol/graph-ts";

import { loadProtocol } from "../helpers/loaders";

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

export function setIsRolloverable(): void {
  const protocol = loadProtocol();
  protocol.rolloverableLCF = dataSource.address();
  protocol.save();
  dataSource.context();
}

export function isRolloverable(): boolean {
  const rolloverableLCF = loadProtocol().rolloverableLCF;
  const lcf = rolloverableLCF ? rolloverableLCF : ByteArray.empty();
  return dataSource.address().equals(lcf);
}
