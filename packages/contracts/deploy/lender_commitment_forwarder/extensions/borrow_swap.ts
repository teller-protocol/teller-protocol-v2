import { DeployFunction } from 'hardhat-deploy/dist/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

import { get_ecosystem_contract_address } from "../../../helpers/ecosystem-contracts-lookup"

/**
 * Where this deployment's swap venue comes from.
 *
 * The router is an address on the chain already, so it is looked up. The
 * quoter may not be: a quoter is a view contract, so it never appears as the
 * target of a transaction and cannot be found by reading chain activity the
 * way a router can. On a chain whose own quoter we cannot point at,
 * deploy_quoter.ts puts this repo's vendored view-quoter there instead, and
 * this reads it back from the deployment.
 *
 * Both resolvers are async and take `hre`. They used to run at module scope
 * against the global `hre`, which meant the skip decision was made once at
 * import time, before the quoter this function depends on could exist.
 */
/**
 * A lookup that answers with whitespace has not answered. hyperevm's quoter
 * entry is the single character `' '`, which is truthy, so `??` keeps it and
 * the constructor gets a space where an address belongs. Trim first, and the
 * fallback below can do its job.
 */
const looked_up = (network: string, name: string): string | undefined => {
  const value = get_ecosystem_contract_address(network, name)?.trim()
  return value ? value : undefined
}

const resolveVenue = async (hre: HardhatRuntimeEnvironment) => {
  const swapRouter = looked_up(hre.network.name, 'uniswapV3SwapRouter')
  const quoter =
    looked_up(hre.network.name, 'uniswapV3Quoter') ??
    (await hre.deployments.getOrNull('Quoter'))?.address

  return { swapRouter, quoter }
}

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')

  const { swapRouter, quoter } = await resolveVenue(hre)

  // skip() has already established both, but a deploy that silently passes a
  // zero address for the quoter would produce a BorrowSwap whose quotes always
  // revert, on an immutable it cannot be told to change.
  if (!swapRouter || !quoter) {
    throw new Error(
      `BorrowSwap on ${hre.network.name}: swapRouter=${swapRouter} quoter=${quoter}`
    )
  }

  await hre.deployProxy('BorrowSwap', {
    unsafeAllow: ['constructor', 'state-variable-immutable'],
    constructorArgs: [await tellerV2.getAddress(), swapRouter, quoter],
  })

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-forwarder:extensions:borrow-swap:deploy'
deployFn.tags = [
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:extensions',
  'lender-commitment-forwarder:extensions:deploy',
  'lender-commitment-forwarder:extensions:borrow-swap',
  'lender-commitment-forwarder:extensions:borrow-swap:deploy',
]
deployFn.dependencies = [
  'teller-v2:deploy',
  // So a chain that deploys its own quoter has one before this reads for it.
  'uniswapv3-quoter:deploy',
]

deployFn.skip = async (hre) => {
  if (!hre.network.live) return true
  const { swapRouter, quoter } = await resolveVenue(hre)
  return !swapRouter || !quoter
}
export default deployFn
