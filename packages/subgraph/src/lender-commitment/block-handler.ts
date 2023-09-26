import {
  Address,
  BigInt,
  dataSource,
  Entity,
  ethereum,
  Value
} from "@graphprotocol/graph-ts";

import { IERC20Metadata } from "../../generated/LenderCommitmentForwarder_ActiveCommitments/IERC20Metadata";
import { LenderCommitmentForwarder } from "../../generated/LenderCommitmentForwarder_ActiveCommitments/LenderCommitmentForwarder";
import { Commitment } from "../../generated/schema";
import { loadProtocol } from "../helpers/loaders";

import {
  updateAvailableTokensFromCommitment,
  updateCommitmentStatus
} from "./updaters";
import { CommitmentStatus } from "./utils";

export function handleActiveCommitments(block: ethereum.Block): void {
  const protocol = loadProtocol();
  handleCommitments(protocol.activeCommitments, block, [
    "checkLenderBalanceAndAllowanceForDeactivation"
  ]);
  const inactiveCommitments = protocol.inactiveCommitments;
  if (inactiveCommitments) {
    handleCommitments(inactiveCommitments, block, [
      "checkLenderBalanceAndAllowanceForActivation"
    ]);
  }
}

function handleCommitments(
  // eslint-disable-next-line @typescript-eslint/ban-types
  commitmentIds: String[],
  block: ethereum.Block,
  // eslint-disable-next-line @typescript-eslint/ban-types
  fnNames: String[]
): void {
  const map = new Entity();

  for (let i = 0; i < commitmentIds.length; i++) {
    const commitment = Commitment.load(commitmentIds[i].toString())!;

    if (commitment.expirationTimestamp.lt(block.timestamp)) {
      updateCommitmentStatus(commitment, CommitmentStatus.Expired);
    } else {
      updateLenderBalanceAndAllowance(commitment, block, map);

      for (let j = 0; j < fnNames.length; j++) {
        if (fnNames[j] === "checkLenderBalanceAndAllowanceForDeactivation") {
          checkLenderBalanceAndAllowanceForDeactivation(commitment);
        } else if (
          fnNames[j] === "checkLenderBalanceAndAllowanceForActivation"
        ) {
          checkLenderBalanceAndAllowanceForActivation(commitment);
        }
      }
    }

    updateAvailableTokensFromCommitment(commitment);
  }
}

export function updateLenderBalanceAndAllowance(
  commitment: Commitment,
  block: ethereum.Block,
  map: Entity
): void {
  const lenderAddress = Address.fromBytes(commitment.lenderAddress);
  const lendingTokenAddress = Address.fromBytes(
    commitment.principalTokenAddress
  );

  const mapKey = `${lenderAddress.toHexString()}-${lendingTokenAddress.toHexString()}`;
  if (map.isSet(mapKey) && map.getBigInt(mapKey).ge(block.number)) {
    return;
  }
  map.set(mapKey, Value.fromBigInt(block.number));

  const lendingToken = IERC20Metadata.bind(lendingTokenAddress);
  const balance = lendingToken.balanceOf(lenderAddress);
  commitment.lenderPrincipalBalance = balance;

  const allowance = lendingToken.allowance(
    lenderAddress,
    LenderCommitmentForwarder.bind(dataSource.address()).getTellerV2()
  );
  commitment.lenderPrincipalAllowance = allowance;

  commitment.save();
}

function checkLenderBalanceAndAllowanceForDeactivation(
  commitment: Commitment
): void {
  if (
    commitment.lenderPrincipalBalance.isZero() ||
    commitment.lenderPrincipalAllowance.isZero()
  ) {
    updateCommitmentStatus(commitment, CommitmentStatus.Inactive);
  }
}

function checkLenderBalanceAndAllowanceForActivation(
  commitment: Commitment
): void {
  if (
    commitment.lenderPrincipalBalance.gt(BigInt.fromU32(0)) &&
    commitment.lenderPrincipalAllowance.gt(BigInt.fromU32(0))
  ) {
    updateCommitmentStatus(commitment, CommitmentStatus.Active);
  }
}
