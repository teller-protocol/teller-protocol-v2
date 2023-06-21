import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const trustedForwarder = await hre.contracts.get('MetaForwarder')

  const tellerV2 = await hre.deployProxy('TellerV2', {
    constructorArgs: [trustedForwarder.address],
    initializer: false,
    redeployImplementation: 'never',
  })

  return true
}

// tags and deployment
deployFn.tags = ['teller-v2', 'teller-v2:deploy']
deployFn.dependencies = ['meta-forwarder']
export default deployFn
