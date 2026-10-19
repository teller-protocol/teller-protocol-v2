import { DeployFunction } from 'hardhat-deploy/dist/types'

import { getNetworkName } from '../../config'
import { isOffersOnlyChain } from '../../config/chains/features'

/**
 * RomeEvmWrappedToken: plain EVM-native ERC20s wrapping Rome's SPL-backed
 * ERC20 wrappers 1:1. Their balances live in EVM storage, so a loan using
 * them does not add Solana token accounts to every transfer.
 *
 * Naming: "Teller EVM <asset>" / "te<asset>". The underlying wrappers already
 * use a "w" prefix (wUSDC, wSOL, wETH); "te" marks the Teller EVM-native
 * layer on top and keeps the underlying asset readable in wallets.
 */
interface WrappedTokenConfig {
  key: string
  underlying: string
  name: string
  symbol: string
}

const tokens = (
  wUSDC: string,
  wSOL: string,
  wETH: string
): WrappedTokenConfig[] => [
  { key: 'wUSDC', underlying: wUSDC, name: 'Teller EVM USDC', symbol: 'teUSDC' },
  { key: 'wSOL', underlying: wSOL, name: 'Teller EVM SOL', symbol: 'teSOL' },
  { key: 'wETH', underlying: wETH, name: 'Teller EVM ETH', symbol: 'teETH' },
]

const ROME_WRAPPED_TOKENS: Record<string, WrappedTokenConfig[]> = {
  hadrian: tokens(
    '0xbce339ba4c3a8de3bb8af1c5539e6ac11da3112d',
    '0x39f36444fcb79b3e691544aee2a832ebef54ca9f',
    '0x02aeace038269f9961c93d04dcacd6fb3adfa55f'
  ),
  rubicon: tokens(
    '0x0952d233b0c254cd375f3bfb3e5869c1a906f9b3',
    '0xc4e29e0f726a906e93277cbbc37bf27a9848a113',
    '0x01e8b3573da1d4b7b4b1ce0932cf07c8af0c92e9'
  ),
}

const deployFn: DeployFunction = async (hre) => {
  const { deployer } = await hre.getNamedAccounts()
  const configs = ROME_WRAPPED_TOKENS[getNetworkName(hre.network)] ?? []

  for (const token of configs) {
    await hre.deployments.deploy(`RomeEvmWrapped_${token.key}`, {
      contract: 'RomeEvmWrappedToken',
      from: deployer,
      args: [token.underlying, token.name, token.symbol],
      skipIfAlreadyDeployed: true,
      log: true,
    })
  }

  return true
}

// tags and deployment
deployFn.id = 'rome:wrapped-tokens:deploy'
deployFn.tags = ['rome:wrapped-tokens', 'rome:wrapped-tokens:deploy']
deployFn.dependencies = []

deployFn.skip = async (hre) =>
  !isOffersOnlyChain(hre.network) ||
  !(getNetworkName(hre.network) in ROME_WRAPPED_TOKENS)

export default deployFn
