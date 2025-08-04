import { DeployFunction } from 'hardhat-deploy/dist/types'

import { get_ecosystem_contract_address } from "../../helpers/ecosystem-contracts-lookup" 


const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('Lender pools V2: Proposing upgrade...')



  const lenderCommitmentGroupV2BeaconProxy = await hre.contracts.get('LenderCommitmentGroupBeaconV2')

  const tellerV2 = await hre.contracts.get('TellerV2')
  const SmartCommitmentForwarder = await hre.contracts.get(
    'SmartCommitmentForwarder'
  )
  const tellerV2Address = await tellerV2.getAddress()


//   const uniswapPricingLibraryV2 = await hre.contracts.get('UniswapPricingLibraryV2')
 
  const smartCommitmentForwarderAddress =
    await SmartCommitmentForwarder.getAddress()

 
let uniswapV3FactoryAddress: string =  get_ecosystem_contract_address( hre.network.name, "uniswapV3Factory" ) ;


  const uniswapPricingLibraryV2 = await hre.deployments.get('UniswapPricingLibraryV2')

 

//this is why the owner of the beacon should be timelock controller ! 
// so we can upgrade it like this . Using a proposal.  This actually goes AROUND the proxy admin, interestingly. 
  await hre.upgrades.proposeBatchTimelock({
    title: 'Lender Pools V2: Upgrade First Deposit',
    description: ` 
# Lender Pools V2

* A patch to fix first deposit logic.
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
          unsafeSkipStorageCheck: true, 
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
deployFn.id = 'lender-commitment-group-beacon-v2:upgrade-first-deposit'
deployFn.tags = ['lender-commitment-group-beacon-v2']
deployFn.dependencies = [
  'teller-v2:deploy',
  'smart-commitment-forwarder:deploy',
  'teller-v2:uniswap-pricing-library-v2',

  'lender-commitment-group-beacon-v2:deploy'
]

deployFn.skip = async (hre) => {
  return !hre.network.live || !['sepolia','polygon'].includes(hre.network.name)
}
export default deployFn
