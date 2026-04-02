import { DeployFunction } from 'hardhat-deploy/dist/types'

import { get_ecosystem_contract_address } from "../../helpers/ecosystem-contracts-lookup"


const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('SwapRolloverLoan G3 (BSC): Proposing upgrade...')

  const swapRolloverLoan = await hre.contracts.get('SwapRolloverLoan')
  const tellerV2 = await hre.contracts.get('TellerV2')

  let uniswapV3FactoryAddress = get_ecosystem_contract_address(hre.network.name, "uniswapV3Factory")
  let weth9Address = get_ecosystem_contract_address(hre.network.name, "weth9")

  await hre.upgrades.proposeBatchTimelock({
    title: 'Swap Rollover Loan G3 Upgrade (BSC PancakeSwap V3)',
    description: `
# SwapRolloverLoan G3 (PancakeSwap V3 Compatibility)

* Adds pancakeV3FlashCallback to support PancakeSwap V3 pools on BSC.
* Extracts shared flash callback logic into _flashCallback internal function.
`,
    _steps: [
      {
        proxy: swapRolloverLoan,
        implFactory: await hre.ethers.getContractFactory('SwapRolloverLoan'),

        opts: {
          unsafeAllow: ['constructor', 'state-variable-immutable'],
          constructorArgs: [
            await tellerV2.getAddress(),
            uniswapV3FactoryAddress,
            weth9Address,
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
deployFn.id = 'lender-commitment-forwarder:extensions:flash-swap-rollover:g3-upgrade-bsc'
deployFn.tags = [
  'proposal',
  'upgrade',
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:extensions',
  'lender-commitment-forwarder:extensions:flash-swap-rollover',
  'lender-commitment-forwarder:extensions:flash-swap-rollover:g3-upgrade-bsc',
]
deployFn.dependencies = [
  'teller-v2:deploy',
  'lender-commitment-forwarder:staging:deploy',
  'lender-commitment-forwarder:extensions:flash-swap-rollover:deploy',
]
deployFn.skip = async (hre) => {
  return hre.network.name !== 'bsc'
}
export default deployFn
