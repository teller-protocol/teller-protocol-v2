import { DeployFunction } from 'hardhat-deploy/dist/types'

import { get_ecosystem_contract_address } from "../../helpers/ecosystem-contracts-lookup"


const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('Lender pools V2: Proposing reentrancy guard upgrade...')



  const lenderCommitmentGroupV2BeaconProxy = await hre.contracts.get('LenderCommitmentGroupBeaconV2')

  const tellerV2 = await hre.contracts.get('TellerV2')
  const SmartCommitmentForwarder = await hre.contracts.get(
    'SmartCommitmentForwarder'
  )
  const tellerV2Address = await tellerV2.getAddress()

  const smartCommitmentForwarderAddress =
    await SmartCommitmentForwarder.getAddress()


let uniswapV3FactoryAddress: string =  get_ecosystem_contract_address( hre.network.name, "uniswapV3Factory" ) ;


  const uniswapPricingLibraryV2 = await hre.deployments.get('UniswapPricingLibraryV2')



  await hre.upgrades.proposeBatchTimelock({
    title: 'Lender Pools V2: Initialize Reentrancy Guard',
    description: `
# Lender Pools V2

* Initializes the ReentrancyGuard via reinitializer(2) on deployed V2 pools.
`,
    _steps: [
      {
        beacon: lenderCommitmentGroupV2BeaconProxy,
        implFactory: await hre.ethers.getContractFactory('LenderCommitmentGroup_Pool_V2', {
          libraries: {
          UniswapPricingLibraryV2:   uniswapPricingLibraryV2.address,
          },
        }),

        opts: {
          unsafeAllow: [
            'constructor',
            'state-variable-immutable',
            'external-library-linking',
          ],
          constructorArgs: [
            tellerV2Address,
            smartCommitmentForwarderAddress,
            uniswapV3FactoryAddress,

          ],
          call: {
            fn: 'initializeReentrancyGuard',
            args: [],
          },
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
deployFn.id = 'lender-commitment-group-beacon-v2:upgrade-reentrancy-guard'
deployFn.tags = ['lender-commitment-group-beacon-v2']
deployFn.dependencies = [
  'teller-v2:deploy',
  'smart-commitment-forwarder:deploy',
  'teller-v2:uniswap-pricing-library-v2',

  'lender-commitment-group-beacon-v2:deploy'
]

deployFn.skip = async (hre) => {
  return !hre.network.live || !['sepolia','polygon','mainnet','arbitrum','base'].includes(hre.network.name)
}
export default deployFn
