import { Network } from 'hardhat/types'

import { getNetworkName } from './index'

/**
 * Which commitment forwarder occupies TellerV2's global forwarder slot.
 *
 * TellerV2Context trusts a forwarder on a market when either the market's own
 * slot names it, or it is the global `lenderCommitmentForwarder`:
 *
 *   _trustedMarketForwarders[_marketId] == _forwarder ||
 *   lenderCommitmentForwarder == _forwarder
 *
 * Two facts make this choice consequential and easy to get wrong:
 *
 *  1. The per-market slot holds ONE address. setTrustedMarketForwarder
 *     overwrites it, so a market cannot trust two forwarders that way. A pools
 *     market spends its slot on the SmartCommitmentForwarder and has none left.
 *  2. The global slot is written once, in TellerV2.initialize, and there is no
 *     setter. Whatever goes in is permanent short of a contract upgrade.
 *
 * Together: the forwarder in the global slot is the only one that can serve a
 * market that also runs pools. Getting it wrong is not a redeploy away.
 */
export type GlobalCommitmentForwarder =
  | 'LenderCommitmentForwarder'
  | 'LenderCommitmentForwarderAlpha'

/**
 * The house default, and what every chain should use unless there is a reason
 * not to: plain LenderCommitmentForwarder global, leaving each market's own
 * slot free for the SmartCommitmentForwarder (pools) or Alpha.
 */
export const DEFAULT_GLOBAL_COMMITMENT_FORWARDER: GlobalCommitmentForwarder =
  'LenderCommitmentForwarder'

/**
 * Chains that deviate from the default.
 *
 * An entry here is a statement about what is already on chain, not a preference
 * we can revise: TellerV2.initialize has run on these networks and the slot is
 * fixed. Changing a line will not move it.
 */
export const GLOBAL_COMMITMENT_FORWARDER_OVERRIDES: Record<
  string,
  GlobalCommitmentForwarder
> = {
  // Robinhood initialized before LenderCommitmentForwarder was deployable here
  // (its deploy script's allowlist omitted the network), so initialize fell
  // through to Alpha and burned it in. Verified on chain 4663:
  // TellerV2.lenderCommitmentForwarder() == the Alpha proxy, and Alpha reads as
  // trusted on every market as a result.
  robinhood: 'LenderCommitmentForwarderAlpha',
}

export const getGlobalCommitmentForwarderName = (
  network: Network
): GlobalCommitmentForwarder =>
  GLOBAL_COMMITMENT_FORWARDER_OVERRIDES[getNetworkName(network)] ??
  DEFAULT_GLOBAL_COMMITMENT_FORWARDER
