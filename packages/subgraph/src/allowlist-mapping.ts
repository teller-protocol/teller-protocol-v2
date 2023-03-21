import { UpdatedAllowList,EnumerableSetAllowlist } from "../generated/EnumerableSetAllowlist/EnumerableSetAllowlist";
import { loadCommitment } from "./helpers/loaders";
import { Address, BigInt, Bytes, store } from "@graphprotocol/graph-ts";

 
 
export function handleUpdatedAllowLists(events: UpdatedAllowList[]): void {
    events.forEach(event => {
        handleUpdatedAllowList(event);
    });
  }


   
export function handleUpdatedAllowList(event: UpdatedAllowList): void {
    
    const enumerableSetAllowlistInstance = EnumerableSetAllowlist.bind(
        event.address
      );

      const commitmentId = event.params.commitmentId.toString();
      const commitment = loadCommitment(commitmentId);

    const borrowers = enumerableSetAllowlistInstance.getAllowedAddresses(
        BigInt.fromString(commitmentId)
      );

      if (borrowers) {
        commitment.commitmentBorrowers = changetype<Bytes[]>(borrowers);
      }


}
