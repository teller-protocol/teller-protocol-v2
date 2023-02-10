import { getNamedSigner, toBN } from 'hardhat'
import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'

const deployFn: DeployFunction = async (hre) => {
  // TellerASRegistry
  const registry = await deploy({
    contract: 'TellerASRegistry',
    hre,
  })
  // TellerEIP712Verifier
  const verifier = await deploy({
    contract: 'TellerASEIP712Verifier',
    hre,
  })
  // TellerAS
  const tellerAS = await deploy({
    contract: 'TellerAS',
    args: [registry.address, verifier.address],
    hre,
  })
}

// tags and deployment
deployFn.tags = ['teller-as']
export default deployFn
