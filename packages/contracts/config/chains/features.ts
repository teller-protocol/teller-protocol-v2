import { Network } from 'hardhat/types'

import { getNetworkName } from '../index'

/**
 * What each chain gets deployed.
 *
 * Every core deploy script used to carry its own hand-written array of network
 * names. There were fifteen of them, formatted a dozen different ways, and
 * onboarding a chain meant finding and editing each one. Missing a single array
 * is silent: the chain deploys, looks healthy, and is quietly missing a
 * contract. That is exactly how Robinhood ended up without
 * LenderCommitmentForwarder, which in turn made TellerV2.initialize fall
 * through to Alpha for the permanent global forwarder slot.
 *
 * One table instead. Adding a chain is one entry here, and what it will and
 * will not get is readable in a single place.
 *
 * The sets below are transcribed from the allowlists they replace, oddities
 * included - sepolia really did lack the SmartCommitmentForwarder, and
 * hyperevm really does lack the Hypernative oracle. This table is a faithful
 * record of what is deployed today, not a tidied-up version of it; correcting
 * a gap is a deliberate change, made on purpose and deployed, not a drive-by
 * edit here.
 */
export type ChainFeature =
  | 'lenderCommitmentForwarder'
  | 'lenderCommitmentForwarderAlpha'
  | 'lenderCommitmentForwarderStaging'
  | 'smartCommitmentForwarder'
  | 'lenderGroupsV1'
  | 'lenderGroupsV2'
  | 'lenderGroupsV3'
  | 'uniswapPricingLibrary'
  | 'uniswapPricingLibraryV2'
  | 'uniswapPricingHelper'
  | 'hypernativeOracle'
  | 'protocolPausingManager'
  // Not a Teller contract: the Uniswap view-quoter this repo vendors, for
  // chains whose own deployment we cannot point at. It is here because it was
  // gated by exactly the kind of hand-written allowlist this table replaces.
  | 'uniswapV3Quoter'

export const CHAIN_FEATURES: Record<string, ChainFeature[]> = {
  mainnet: [
    'lenderCommitmentForwarderAlpha',
    'smartCommitmentForwarder',
    'lenderGroupsV2',
    'lenderGroupsV3',
    'uniswapPricingLibrary',
    'uniswapPricingLibraryV2',
    'hypernativeOracle',
    'protocolPausingManager',
  ],
  mainnet_live_fork: [
    'lenderCommitmentForwarderAlpha',
    'smartCommitmentForwarder',
    'lenderGroupsV2',
    'lenderGroupsV3',
    'uniswapPricingLibrary',
    'uniswapPricingLibraryV2',
    'protocolPausingManager',
  ],
  polygon: [
    'lenderCommitmentForwarderAlpha',
    'smartCommitmentForwarder',
    'lenderGroupsV2',
    'lenderGroupsV3',
    'uniswapPricingLibrary',
    'uniswapPricingLibraryV2',
    'uniswapPricingHelper',
    'hypernativeOracle',
    'protocolPausingManager',
    'uniswapV3Quoter',
  ],
  arbitrum: [
    'lenderCommitmentForwarderAlpha',
    'smartCommitmentForwarder',
    'lenderGroupsV2',
    'lenderGroupsV3',
    'uniswapPricingLibraryV2',
    'hypernativeOracle',
    'protocolPausingManager',
  ],
  base: [
    'lenderCommitmentForwarderAlpha',
    'smartCommitmentForwarder',
    'lenderGroupsV2',
    'lenderGroupsV3',
    'uniswapPricingLibraryV2',
    'hypernativeOracle',
    'protocolPausingManager',
  ],
  optimism: [
    'lenderCommitmentForwarderAlpha',
    'smartCommitmentForwarder',
    'lenderGroupsV2',
    'lenderGroupsV3',
    'uniswapPricingLibrary',
    'uniswapPricingLibraryV2',
    'protocolPausingManager',
  ],
  bsc: [
    'lenderCommitmentForwarderAlpha',
    'smartCommitmentForwarder',
    'lenderGroupsV2',
    'uniswapPricingLibraryV2',
    'uniswapPricingHelper',
    'hypernativeOracle',
    'protocolPausingManager',
  ],
  apechain: [
    'lenderCommitmentForwarderAlpha',
    'smartCommitmentForwarder',
    'lenderGroupsV2',
    'lenderGroupsV3',
    'uniswapPricingLibraryV2',
    'uniswapPricingHelper',
    'hypernativeOracle',
    'protocolPausingManager',
  ],
  xdc: [
    'lenderCommitmentForwarderAlpha',
    'smartCommitmentForwarder',
    'lenderGroupsV2',
    'uniswapPricingLibraryV2',
    'uniswapPricingHelper',
    'hypernativeOracle',
    'protocolPausingManager',
  ],
  katana: [
    'lenderCommitmentForwarder',
    'lenderCommitmentForwarderAlpha',
    'smartCommitmentForwarder',
    'lenderGroupsV2',
    'lenderGroupsV3',
    'uniswapPricingLibrary',
    'uniswapPricingLibraryV2',
    'protocolPausingManager',
    'uniswapV3Quoter',
  ],
  hyperevm: [
    'lenderCommitmentForwarder',
    'lenderCommitmentForwarderAlpha',
    'smartCommitmentForwarder',
    'lenderGroupsV2',
    'lenderGroupsV3',
    'protocolPausingManager',
    'uniswapV3Quoter',
  ],
  // Arc gets plain LenderCommitmentForwarder, unlike Robinhood. Omitting it
  // there is what left TellerV2.initialize falling through to Alpha for the
  // permanent global forwarder slot, which has no setter - so every lending
  // offer on that chain has to route through Alpha forever. One line here is
  // the whole difference.
  arc: [
    'lenderCommitmentForwarder',
    'lenderCommitmentForwarderAlpha',
    'smartCommitmentForwarder',
    'lenderGroupsV2',
    'uniswapPricingLibraryV2',
    'uniswapPricingHelper',
    'hypernativeOracle',
    'protocolPausingManager',
    // No vendored quoter: Uniswap ships one on Arc, and it answers factory()
    // with the chain's v3 factory. The vendored copy exists for chains with
    // none to point at, and deploying it here would be a second quoter to keep
    // in step with the first.
  ],
  robinhood: [
    'lenderCommitmentForwarder',
    'lenderCommitmentForwarderAlpha',
    'smartCommitmentForwarder',
    'lenderGroupsV2',
    'uniswapPricingLibraryV2',
    'uniswapPricingHelper',
    'hypernativeOracle',
    'protocolPausingManager',
    'uniswapV3Quoter',
  ],
  sepolia: [
    'lenderCommitmentForwarder',
    'lenderCommitmentForwarderAlpha',
    'lenderCommitmentForwarderStaging',
    'lenderGroupsV1',
    'lenderGroupsV2',
    'lenderGroupsV3',
    'uniswapPricingLibrary',
    'uniswapPricingLibraryV2',
  ],
  localhost: ['smartCommitmentForwarder', 'protocolPausingManager'],
}

/**
 * Whether a chain gets this contract. Unknown networks get nothing, which is
 * the same answer the allowlists gave.
 */
export const chainSupports = (
  network: Network,
  feature: ChainFeature
): boolean => (CHAIN_FEATURES[getNetworkName(network)] ?? []).includes(feature)

/**
 * A `deployFn.skip` that defers to the table. Live-network check included,
 * since every allowlist this replaces had one.
 */
export const skipUnlessChainSupports =
  (feature: ChainFeature) =>
  async (hre: { network: Network }): Promise<boolean> =>
    !hre.network.live || !chainSupports(hre.network, feature)
