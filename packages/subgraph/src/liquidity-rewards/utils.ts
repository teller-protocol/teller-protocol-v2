export enum AllocationStatus {
  Active,
  Expired,
  Deleted,
  Drained
}


const AllocationStatusValues = new Array<string>(10);
AllocationStatusValues[AllocationStatus.Active] = "Active";
AllocationStatusValues[AllocationStatus.Expired] = "Expired";
AllocationStatusValues[AllocationStatus.Deleted] = "Deleted";
AllocationStatusValues[AllocationStatus.Drained] = "Drained";

export function allocationStatusToEnum(status: string): AllocationStatus {
  return AllocationStatusValues.indexOf(status);
}

export function allocationStatusToString(status: AllocationStatus): string {
  return AllocationStatusValues[status];
}

 