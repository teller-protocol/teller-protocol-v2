import { DeployFunction } from 'hardhat-deploy/dist/types'


import { get_ecosystem_contract_address } from "../../helpers/ecosystem-contracts-lookup" 


const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('Lendergroups: Proposing upgrade...')



  const lenderCommitmentGroupBeaconProxy = await hre.contracts.get('LenderCommitmentGroupBeacon')

  const tellerV2 = await hre.contracts.get('TellerV2')
  const SmartCommitmentForwarder = await hre.contracts.get(
    'SmartCommitmentForwarder'
  )
  const tellerV2Address = await tellerV2.getAddress()

  const smartCommitmentForwarderAddress =
    await SmartCommitmentForwarder.getAddress()


let uniswapV3FactoryAddress: string =  get_ecosystem_contract_address( hre.network.name, "uniswapV3Factory" ) ;
  const uniswapPricingLibrary = await hre.deployments.get('UniswapPricingLibrary')

 

//this is why the owner of the beacon should be timelock controller ! 
// so we can upgrade it like this . Using a proposal.  This actually goes AROUND the proxy admin, interestingly. 
  await hre.upgrades.proposeBatchTimelock({
    title: 'LenderGroups: Liq Pause',
    description: ` 
# LenderGroups

* A patch to add pausing of liquidations.
`,
    _steps: [
      {
        beacon: lenderCommitmentGroupBeaconProxy,
        implFactory: await hre.ethers.getContractFactory('LenderCommitmentGroup_Smart', {
          libraries: {
            UniswapPricingLibrary: uniswapPricingLibrary.address,
          },
        }),

        opts: {
          // unsafeSkipStorageCheck: true, 
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
deployFn.id = 'lender-commitment-group-beacon:upgrade-liq-pause'
deployFn.tags = ['lender-commitment-group-beacon']
deployFn.dependencies = [
  'teller-v2:deploy',
  'smart-commitment-forwarder:deploy',
  'teller-v2:uniswap-pricing-library',
  'lender-commitment-group-beacon:deploy'
]

deployFn.skip = async (hre) => {
  return !hre.network.live || !['sepolia','polygon','mainnet'].includes(hre.network.name)
}
export default deployFn
