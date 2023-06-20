import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'

const deployFn: DeployFunction = async (hre) => {
  const registry = await deploy({
    contract: 'TellerASRegistry',
    hre,
  })
  const verifier = await deploy({
    contract: 'TellerASEIP712Verifier',
    hre,
  })
  const tellerAS = await deploy({
    contract: 'TellerAS',
    args: [registry.address, verifier.address],
    hre,
  })

  const marketRegistry = await hre.deployProxy('MarketRegistry', {
    initArgs: [tellerAS.address],
    redeployImplementation: 'never',
  })

  return true
}

// tags and deployment
deployFn.tags = ['market-registry']
deployFn.dependencies = []
export default deployFn
