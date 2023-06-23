import { DeployFunction } from 'hardhat-deploy/dist/types'
import { LenderManager } from 'types/typechain'

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')
  const lenderManager = await hre.contracts.get<LenderManager>('LenderManager')
  const { wait } = await lenderManager.transferOwnership(tellerV2.address)
  await wait(1)

  return true
}

// tags and deployment
deployFn.id = 'lender-manager:transfer-ownership'
deployFn.tags = ['lender-manager', 'lender-manager:transfer-ownership']
deployFn.dependencies = ['teller-v2', 'lender-manager:deploy']
export default deployFn
