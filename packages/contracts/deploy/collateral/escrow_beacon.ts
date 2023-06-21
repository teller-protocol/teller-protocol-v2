import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const collateralEscrowBeacon = await hre.deployBeacon('CollateralEscrowV1', {
    redeployImplementation: 'never',
  })

  return true
}

// tags and deployment
deployFn.id = 'collateral:escrow-beacon'
deployFn.tags = ['collateral', 'collateral:escrow-beacon']
deployFn.dependencies = []
export default deployFn
