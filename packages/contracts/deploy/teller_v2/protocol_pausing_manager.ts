import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  
  const protocolPausingManager = await hre.deployProxy(
    'ProtocolPausingManager',
    {
      unsafeAllow: ['constructor', 'state-variable-immutable'],
      constructorArgs: [
        
      ],

        //call init with no args
      initArgs: [
        
      ],
    }
  )

  
  const { protocolOwnerSafe } = await hre.getNamedAccounts()
  hre.log('Transferring ownership of ProtocolPausingManager to Gnosis Safe...')
  await protocolPausingManager.transferOwnership(protocolOwnerSafe)
  hre.log('done.')

    
  // need to xfer ownership ! 

  return true
}

// tags and deployment
deployFn.id = 'protocol-pausing-manager:deploy'
deployFn.tags = [
  'protocol-pausing-manager',
  'protocol-pausing-manager:deploy',
]
deployFn.dependencies = ['teller-v2:deploy' ]

deployFn.skip = async (hre) => {
  return (
    !hre.network.live || !['localhost', 'polygon'].includes(hre.network.name)
  )
}
export default deployFn
