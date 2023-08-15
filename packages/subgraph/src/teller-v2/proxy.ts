import { Address, BigInt } from "@graphprotocol/graph-ts";

import { Upgraded } from "../../generated/TellerV2_Proxy/Proxy";
import { getBid, loadBidById } from "../helpers/loaders";

export function handleTellerV2Upgraded(event: Upgraded): void {
  if (
    event.params.implementation.equals(
      Address.fromString("0xf39674f4d3878a732cb4c70b377c013affb89c1f")
    )
  ) {
    for (let i = 62; i < 66; i++) {
      const storedBid = getBid(event.address, BigInt.fromI32(i));
      const bid = loadBidById(BigInt.fromI32(i));
      if (bid.bidId) {
        bid.paymentCycleAmount = storedBid.value6.paymentCycleAmount;
        bid.save();
      }
    }
  }
}
