import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const trustedForwarder = await hre.contracts.get('MetaForwarder')

  const tellerV2 = await hre.deployProxy('TellerV2', {
    unsafeAllow: ['constructor', 'state-variable-immutable'],
    constructorArgs: [trustedForwarder.address],
    initializer: false,
  })

  return true
}

// tags and deployment
deployFn.id = 'teller-v2:deploy'
deployFn.tags = ['teller-v2', 'teller-v2:deploy']
deployFn.dependencies = ['meta-forwarder:deploy']
export default deployFn
