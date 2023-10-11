import { dataSource } from "@graphprotocol/graph-ts";

export function isV2(): boolean {
  const ctx = dataSource.context();
  return !!ctx.isSet("isV2") && ctx.getBoolean("isV2");
}
