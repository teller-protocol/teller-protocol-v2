import { Address, BigInt } from "@graphprotocol/graph-ts";

import { MarketRegistry } from "../../generated/MarketRegistry_Proxy/MarketRegistry";
import { Upgraded } from "../../generated/MarketRegistry_Proxy/Proxy";
import { loadMarketById } from "../helpers/loaders";

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
