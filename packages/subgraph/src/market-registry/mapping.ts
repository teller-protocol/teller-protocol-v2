import { Address, BigInt } from "@graphprotocol/graph-ts";

import {
  BorrowerAttestation,
  BorrowerExitMarket,
  LenderAttestation,
  LenderExitMarket,
  MarketClosed,
  MarketCreated,
  MarketRegistry,
  SetBidExpirationTime,
  SetMarketBorrowerAttestation,
  SetMarketFee,
  SetMarketFeeRecipient,
  SetMarketLenderAttestation,
  SetMarketOwner,
  SetMarketPaymentType,
  SetMarketURI,
  SetPaymentCycle,
  SetPaymentCycleDuration,
  SetPaymentDefaultDuration
} from "../../generated/MarketRegistry/MarketRegistry";
import { Upgraded } from "../../generated/MarketRegistry_Proxy/Proxy";
import { Borrower, Lender, MarketPlace } from "../../generated/schema";
import {
  loadBorrowerByMarketId,
  loadLenderByMarketId,
  loadMarketById
} from "../helpers/loaders";

export function handleMarketCreated(event: MarketCreated): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  marketPlace.owner = event.params.owner;
  // market owner is the default fee recipient
  marketPlace.feeRecipient = event.params.owner;

  const marketPlaceInstance = MarketRegistry.bind(event.address);
  if (
    !marketPlaceInstance.try_isVerifiedBorrower(
      event.params.marketId,
      Address.zero()
    ).reverted
  ) {
    marketPlace.borrowerAttestationRequired = !marketPlaceInstance.isVerifiedBorrower(
      event.params.marketId,
      Address.zero()
    ).value0;
  }
  if (
    !marketPlaceInstance.try_isVerifiedLender(
      event.params.marketId,
      Address.zero()
    ).reverted
  ) {
    marketPlace.lenderAttestationRequired = !marketPlaceInstance.isVerifiedLender(
      event.params.marketId,
      Address.zero()
    ).value0;
  }
  marketPlace.isMarketOpen = true;
  marketPlace.save();
}

export function handleMarketsCreated(events: MarketCreated[]): void {
  events.forEach(event => {
    handleMarketCreated(event);
  });
}

export function handleMarketClosed(event: MarketClosed): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  marketPlace.isMarketOpen = false;
  marketPlace.save();
}

export function handleMarketsClosed(events: MarketClosed[]): void {
  events.forEach(event => {
    handleMarketClosed(event);
  });
}

export function handleSetMarketOwner(event: SetMarketOwner): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  marketPlace.owner = event.params.newOwner;

  marketPlace.save();
}

export function handleSetMarketFeeRecipient(
  event: SetMarketFeeRecipient
): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  marketPlace.feeRecipient = event.params.newRecipient;

  marketPlace.save();
}

export function handleSetMarketURI(event: SetMarketURI): void {
  const marketPlace = loadMarketById(event.params.marketId.toString());
  marketPlace.metadataURI = event.params.uri;

  marketPlace.save();
}

export function handleSetMarketURIs(events: SetMarketURI[]): void {
  events.forEach(event => {
    handleSetMarketURI(event);
  });
}

export function handleSetMarketPaymentType(event: SetMarketPaymentType): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  if (event.params.paymentType == i32(0)) {
    marketPlace.paymentType = "EMI";
  } else if (event.params.paymentType == i32(1)) {
    marketPlace.paymentType = "Bullet";
  }

  marketPlace.save();
}

export function handleSetMarketPaymentTypes(
  events: SetMarketPaymentType[]
): void {
  events.forEach(event => {
    handleSetMarketPaymentType(event);
  });
}

export function handleSetPaymentCycleDuration(
  event: SetPaymentCycleDuration
): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  marketPlace.paymentCycleDuration = event.params.duration;

  marketPlace.save();
}

export function handleSetPaymentCycleDurations(
  events: SetPaymentCycleDuration[]
): void {
  events.forEach(event => {
    handleSetPaymentCycleDuration(event);
  });
}

export function handleSetPaymentCycle(event: SetPaymentCycle): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  marketPlace.paymentCycleDuration = event.params.value;

  if (event.params.paymentCycleType == i32(0)) {
    marketPlace.paymentCycleType = "Seconds";
  } else if (event.params.paymentCycleType == i32(1)) {
    marketPlace.paymentCycleType = "Monthly";
  }

  marketPlace.save();
}

export function handleSetPaymentCycles(events: SetPaymentCycle[]): void {
  events.forEach(event => {
    handleSetPaymentCycle(event);
  });
}

export function handleSetPaymentDefaultDuration(
  event: SetPaymentDefaultDuration
): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  marketPlace.paymentDefaultDuration = event.params.duration;

  marketPlace.save();
}

export function handleSetPaymentDefaultDurations(
  events: SetPaymentDefaultDuration[]
): void {
  events.forEach(event => {
    handleSetPaymentDefaultDuration(event);
  });
}

export function handleSetBidExpirationTime(event: SetBidExpirationTime): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  marketPlace.bidExpirationTime = event.params.duration;

  marketPlace.save();
}

export function handleSetBidExpirationTimes(
  events: SetBidExpirationTime[]
): void {
  events.forEach(event => {
    handleSetBidExpirationTime(event);
  });
}

export function handleSetMarketFee(event: SetMarketFee): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );

  marketPlace.marketplaceFeePercent = BigInt.fromI32(event.params.feePct);

  marketPlace.save();
}

export function handleSetMarketFees(events: SetMarketFee[]): void {
  events.forEach(event => {
    handleSetMarketFee(event);
  });
}

export function handleSetLenderAttestationRequired(
  event: SetMarketLenderAttestation
): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  marketPlace.lenderAttestationRequired = event.params.required;

  marketPlace.save();
}

export function handleSetBorrowerAttestationRequired(
  event: SetMarketBorrowerAttestation
): void {
  const marketPlace: MarketPlace = loadMarketById(
    event.params.marketId.toString()
  );
  marketPlace.borrowerAttestationRequired = event.params.required;

  marketPlace.save();
}

export function handleLenderAttestation(event: LenderAttestation): void {
  const market = loadMarketById(event.params.marketId.toString());
  const lender: Lender = loadLenderByMarketId(
    event.params.lender,
    market.id,
    event.block.timestamp
  );
  lender.attestedTimestamp = event.block.timestamp;
  lender.isAttested = true;

  lender.save();
}

export function handleLenderAttestations(events: LenderAttestation[]): void {
  events.forEach(event => {
    handleLenderAttestation(event);
  });
}

export function handleBorrowerAttestation(event: BorrowerAttestation): void {
  const borrower: Borrower = loadBorrowerByMarketId(
    event.params.borrower,
    event.params.marketId.toString(),
    event.block.timestamp
  );
  borrower.attestedTimestamp = event.block.timestamp;
  borrower.isAttested = true;

  borrower.save();
}

export function handleBorrowerAttestations(
  events: BorrowerAttestation[]
): void {
  events.forEach(event => {
    handleBorrowerAttestation(event);
  });
}

export function handleLenderExitMarket(event: LenderExitMarket): void {
  const market = loadMarketById(event.params.marketId.toString());
  const lender = loadLenderByMarketId(
    event.params.lender,
    market.id,
    event.block.timestamp
  );

  lender.isAttested = false;
  lender.save();
}

export function handleLenderExitMarkets(events: LenderExitMarket[]): void {
  events.forEach(event => {
    handleLenderExitMarket(event);
  });
}

export function handleBorrowerExitMarket(event: BorrowerExitMarket): void {
  const borrower = loadBorrowerByMarketId(
    event.params.borrower,
    event.params.marketId.toString(),
    event.block.timestamp
  );

  borrower.isAttested = false;
  borrower.save();
}

export function handleBorrowerExitMarkets(events: BorrowerExitMarket[]): void {
  events.forEach(event => {
    handleBorrowerExitMarket(event);
  });
}

export function handleMarketRegistryUpgraded(event: Upgraded): void {
  const marketPlaceInstance = MarketRegistry.bind(event.address);
  if (
    event.params.implementation.equals(
      Address.fromString("0xb43707f26D6356ae753E9C92d3C94D23c70c4057")
    ) // Polygon
  ) {
    const marketCount = marketPlaceInstance.marketCount();
    for (let i = 1; i <= marketCount.toI32(); i++) {
      if (
        !marketPlaceInstance.try_getMarketAttestationRequirements(
          BigInt.fromI32(i)
        ).reverted
      ) {
        const attestationsRequired = marketPlaceInstance.getMarketAttestationRequirements(
          BigInt.fromI32(i)
        );
        const market = loadMarketById(i.toString());
        if (market) {
          market.lenderAttestationRequired = attestationsRequired.value0;
          market.borrowerAttestationRequired = attestationsRequired.value1;
          market.save();
        }
      }
    }
  }

  if (
    event.params.implementation.equals(
      Address.fromString("0xb8bFfcC58d97581b85d67C80556A4e2e05d36bEc")
    ) || // Polygon
    event.params.implementation.equals(
      Address.fromString("0x54B1b79531c80DA391638D040B58ABDB193326F3")
    ) || // Mainnet
    event.params.implementation.equals(
      Address.fromString("0xC149E7081F08EA3310FC4AAca8c31fD972f7B06c")
    ) // Goerli
  ) {
    const marketCount = marketPlaceInstance.marketCount();
    for (let i = 1; i <= marketCount.toI32(); i++) {
      const marketId = BigInt.fromI32(i);
      const market = loadMarketById(marketId.toString());
      if (market) {
        const requirements = marketPlaceInstance.getMarketAttestationRequirements(
          marketId
        );
        market.lenderAttestationRequired = requirements.value0;
        market.borrowerAttestationRequired = requirements.value1;
        market.save();
      }
    }
  }
}
