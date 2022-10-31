import { getNamedSigner, toBN } from 'hardhat'
import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'

const deployFn: DeployFunction = async (hre) => {
  const deployer = await getNamedSigner('deployer')
  // TLR
  await deploy({
    contract: 'TLR',
    args: [toBN('100000000', '18'), await deployer.getAddress()], // Switch to DAO for mainnet, set for Mumbai
    hre,
  })
}

// tags and deployment
deployFn.tags = ['tlr']
export default deployFn
