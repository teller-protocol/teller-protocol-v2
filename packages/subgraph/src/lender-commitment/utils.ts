export enum CommitmentStatus {
  Active,
  Expired,
  Deleted,
  Drained
}

const CommitmentStatusValues = new Array<string>(10);
CommitmentStatusValues[CommitmentStatus.Active] = "Active";
CommitmentStatusValues[CommitmentStatus.Expired] = "Expired";
CommitmentStatusValues[CommitmentStatus.Deleted] = "Deleted";
CommitmentStatusValues[CommitmentStatus.Drained] = "Drained";

export function commitmentStatusToEnum(status: string): CommitmentStatus {
  return CommitmentStatusValues.indexOf(status);
}

export function commitmentStatusToString(status: CommitmentStatus): string {
  return CommitmentStatusValues[status];
}
