import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {


  const tellerV2 = await hre.contracts.get('TellerV2')
  const SmartCommitmentForwarder = await hre.contracts.get(
    'SmartCommitmentForwarder'
  )
  const LenderGroupsBeacon = await hre.contracts.get(
    'LenderCommitmentGroupBeaconV3'
  )

  const LenderGroupsBeaconAddress =
  await LenderGroupsBeacon.getAddress()

  

  const lenderGroupsFactory = await hre.deployProxy(
    'LenderCommitmentGroupFactory_V3',
    {
      unsafeAllow: ['constructor', 'state-variable-immutable'],
      
      initArgs: [
        LenderGroupsBeaconAddress
      ],
      
    }
  )

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-group-factory-v3:deploy'
deployFn.tags = ['lender-commitment-group-factory-v3']
deployFn.dependencies = [
  'teller-v2:deploy',
  'teller-v2:init',
  'smart-commitment-forwarder:deploy',
  'lender-commitment-group-beacon-v3:deploy'
]

deployFn.skip = async (hre) => {
  return !hre.network.live || !['sepolia','polygon','mainnet','mainnet_live_fork','arbitrum','base','optimism' ,'katana','hyperevm'].includes(hre.network.name)
}
export default deployFn