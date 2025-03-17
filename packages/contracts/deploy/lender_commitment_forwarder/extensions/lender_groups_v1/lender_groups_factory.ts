import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {


  const tellerV2 = await hre.contracts.get('TellerV2')
  const SmartCommitmentForwarder = await hre.contracts.get(
    'SmartCommitmentForwarder'
  )
  const LenderGroupsBeacon = await hre.contracts.get(
    'LenderCommitmentGroupBeacon'
  )

  const LenderGroupsBeaconAddress =
  await LenderGroupsBeacon.getAddress()

 
  //const networkName = hre.network.name

  const lenderGroupsFactory = await hre.deployProxy(
    'LenderCommitmentGroupFactory',
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
deployFn.id = 'lender-commitment-group-factory:deploy'
deployFn.tags = ['lender-commitment-group-factory']
deployFn.dependencies = [
  'teller-v2:deploy',
  'teller-v2:init',
  'smart-commitment-forwarder:deploy',
  'lender-commitment-group-beacon:deploy'
]

deployFn.skip = async (hre) => {
  return !hre.network.live || !['sepolia','polygon','mainnet','mainnet_live_fork','arbitrum','base' ].includes(hre.network.name)
}
export default deployFn