import { upgrades } from 'hardhat'
import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'
import { CollateralManager } from 'types/typechain'

const deployFn: DeployFunction = async (hre) => {
  const collateralEscrowV1 = await hre.ethers.getContractFactory(
    'CollateralEscrowV1'
  )
  // Deploy escrow beacon implementation
  const collateralEscrowBeacon = await upgrades.deployBeacon(collateralEscrowV1)
  await collateralEscrowBeacon.deployed()

  await deploy<CollateralManager>({
    name: 'CollateralManager',
    contract: 'CollateralManager',
    args: [],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init: {
          methodName: 'initialize',
          args: [collateralEscrowBeacon.address],
        },
      },
      upgradeIndex: 0,
    },
    skipIfAlreadyDeployed: true,
    hre,
  })
}

// tags and deployment
deployFn.tags = ['collateral-manager']
deployFn.dependencies = []
export default deployFn
