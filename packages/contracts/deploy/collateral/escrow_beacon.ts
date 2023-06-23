import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const collateralEscrowBeacon = await hre.deployBeacon('CollateralEscrowV1', {
    customName: 'CollateralEscrowBeacon',
  })

  return true
}

// tags and deployment
deployFn.id = 'collateral:escrow-beacon:deploy'
deployFn.tags = [
  'collateral',
  'collateral:escrow-beacon',
  'collateral:escrow-beacon:deploy',
]
deployFn.dependencies = []
export default deployFn
