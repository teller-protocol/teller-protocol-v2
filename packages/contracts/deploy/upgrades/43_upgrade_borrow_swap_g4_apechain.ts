import { DeployFunction } from 'hardhat-deploy/dist/types'

import { get_ecosystem_contract_address } from "../../helpers/ecosystem-contracts-lookup"


const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('BorrowSwap G4 (ApeChain): Deploying AlgebraSwapAdapter + proposing proxy upgrade...')

  const borrowSwap = await hre.contracts.get('BorrowSwap')
  const tellerV2 = await hre.contracts.get('TellerV2')

  const uniswapV3SwapRouter = get_ecosystem_contract_address(hre.network.name, "uniswapV3SwapRouter")
  const uniswapV3Quoter = get_ecosystem_contract_address(hre.network.name, "uniswapV3Quoter")

  if (!uniswapV3SwapRouter || !uniswapV3Quoter) {
    throw new Error(`Missing swap router or quoter for network ${hre.network.name}`)
  }

  // 1. Deploy AlgebraSwapAdapter (Camelot V3 compatible)
  const algebraSwapAdapter = await hre.deployments.deploy('AlgebraSwapAdapter', {
    from: (await hre.getNamedAccounts()).deployer,
    contract: 'AlgebraSwapAdapter',
    args: [uniswapV3SwapRouter, uniswapV3Quoter],
    log: true,
  })

  hre.log(`AlgebraSwapAdapter deployed at: ${algebraSwapAdapter.address}`)

  // 2. Upgrade BorrowSwap proxy from G3 -> G4
  await hre.upgrades.proposeBatchTimelock({
    title: 'BorrowSwap G4 Upgrade (ApeChain Camelot V3)',
    description: `
# BorrowSwap G4 (Adapter Pattern)

* Upgrades BorrowSwap from G3 to G4 on ApeChain.
* Replaces hardcoded Uniswap V3 router/quoter with pluggable ISwapAdapter pattern.
* Uses AlgebraSwapAdapter configured for Camelot V3 (fee-less path encoding).
* Fixes path encoding mismatch that caused G3 quoteExactInput to revert on Algebra DEXes.
`,
    _steps: [
      {
        proxy: borrowSwap,
        implFactory: await hre.ethers.getContractFactory('BorrowSwap_G4'),

        opts: {
          unsafeAllow: ['constructor', 'state-variable-immutable'],
          constructorArgs: [
            await tellerV2.getAddress(),
            algebraSwapAdapter.address,
          ],
        },
      },
    ],
  })

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-forwarder:extensions:borrow-swap:g4-upgrade-apechain'
deployFn.tags = [
  'proposal',
  'upgrade',
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:extensions',
  'lender-commitment-forwarder:extensions:borrow-swap',
  'lender-commitment-forwarder:extensions:borrow-swap:g4-upgrade-apechain',
]
deployFn.dependencies = [
  'teller-v2:deploy',
  'lender-commitment-forwarder:extensions:borrow-swap:deploy',
]
deployFn.skip = async (hre) => {
  return hre.network.name !== 'apechain'
}
export default deployFn
