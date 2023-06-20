import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployManagerFn: DeployFunction = async (hre) => {
  const collateralEscrowImplFactory = await hre.ethers.getContractFactory(
    'CollateralEscrowV1'
  )
  // TODO: create helper script and save beacon deployment
  const collateralEscrowBeacon = await hre.upgrades.deployBeacon(
    collateralEscrowImplFactory,
    {
      redeployImplementation: 'never',
    }
  )
  const collateralManager = await hre.deployProxy('CollateralManager', {
    redeployImplementation: 'never',
    initArgs: [collateralEscrowBeacon.address, tellerV2.address],
  })

  return true
}

// tags and deployment
deployManagerFn.id = 'collateral'
deployManagerFn.tags = ['collateral']
deployManagerFn.dependencies = ['teller-v2']
export default deployManagerFn
