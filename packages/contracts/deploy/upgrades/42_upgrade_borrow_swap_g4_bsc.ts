import { DeployFunction } from 'hardhat-deploy/dist/types'

import { get_ecosystem_contract_address } from "../../helpers/ecosystem-contracts-lookup"


const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('BorrowSwap G4 (BSC): Deploying UniswapV3SwapAdapter + proposing proxy upgrade...')

  const borrowSwap = await hre.contracts.get('BorrowSwap')
  const tellerV2 = await hre.contracts.get('TellerV2')

  const uniswapV3SwapRouter = get_ecosystem_contract_address(hre.network.name, "uniswapV3SwapRouter")
  const uniswapV3Quoter = get_ecosystem_contract_address(hre.network.name, "uniswapV3Quoter")

  if (!uniswapV3SwapRouter || !uniswapV3Quoter) {
    throw new Error(`Missing swap router or quoter for network ${hre.network.name}`)
  }

  // 1. Deploy UniswapV3SwapAdapter (PancakeSwap V3 compatible)
  const uniswapV3SwapAdapter = await hre.deployments.deploy('UniswapV3SwapAdapter', {
    from: (await hre.getNamedAccounts()).deployer,
    contract: 'UniswapV3SwapAdapter',
    args: [uniswapV3SwapRouter, uniswapV3Quoter],
    log: true,
  })

  hre.log(`UniswapV3SwapAdapter deployed at: ${uniswapV3SwapAdapter.address}`)

  // 2. Upgrade BorrowSwap proxy from G3 -> G4
  await hre.upgrades.proposeBatchTimelock({
    title: 'BorrowSwap G4 Upgrade (BSC PancakeSwap V3)',
    description: `
# BorrowSwap G4 (Adapter Pattern)

* Upgrades BorrowSwap from G3 to G4 on BSC.
* Replaces hardcoded Uniswap V3 router/quoter with pluggable ISwapAdapter pattern.
* Uses UniswapV3SwapAdapter configured for PancakeSwap V3 (0.25% default fee).
* Fixes quoter STATICCALL issue via IQuoterV4 (non-view interface).
* Fixes swap deadline field for PancakeSwap V3 compatibility.
`,
    _steps: [
      {
        proxy: borrowSwap,
        implFactory: await hre.ethers.getContractFactory('BorrowSwap'),

        opts: {
          unsafeAllow: ['constructor', 'state-variable-immutable'],
          constructorArgs: [
            await tellerV2.getAddress(),
            uniswapV3SwapAdapter.address,
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
deployFn.id = 'lender-commitment-forwarder:extensions:borrow-swap:g4-upgrade-bsc'
deployFn.tags = [
  'proposal',
  'upgrade',
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:extensions',
  'lender-commitment-forwarder:extensions:borrow-swap',
  'lender-commitment-forwarder:extensions:borrow-swap:g4-upgrade-bsc',
]
deployFn.dependencies = [
  'teller-v2:deploy',
  'lender-commitment-forwarder:extensions:borrow-swap:deploy',
]
deployFn.skip = async (hre) => {
  return hre.network.name !== 'bsc'
}
export default deployFn
