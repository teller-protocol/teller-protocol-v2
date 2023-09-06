import { ethereum } from "@graphprotocol/graph-ts";

import { Commitment } from "../../generated/schema";
import { loadProtocol } from "../helpers/loaders";

import {
  updateAvailableTokensFromCommitment,
  updateCommitmentStatus
} from "./updaters";
import { CommitmentStatus } from "./utils";

export function handleActiveCommitments(block: ethereum.Block): void {
  const protocol = loadProtocol();
  const activeCommitments = protocol.activeCommitments;
  for (let i = 0; i < activeCommitments.length; i++) {
    const commitmentId = protocol.activeCommitments[i];
    const commitment = Commitment.load(commitmentId)!;

    // TODO: check the lender's token balance + allowance

    if (commitment.expirationTimestamp.lt(block.timestamp)) {
      updateCommitmentStatus(commitment, CommitmentStatus.Expired);
      updateAvailableTokensFromCommitment(commitment);
    }
  }
}
