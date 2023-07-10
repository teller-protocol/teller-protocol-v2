import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const collateralEscrowBeacon = await hre.contracts.get(
    'CollateralEscrowBeacon'
  )
  const tellerV2 = await hre.contracts.get('TellerV2')

  const collateralManager = await hre.deployProxy('CollateralManager', {
    initArgs: [collateralEscrowBeacon.address, tellerV2.address],
  })

  return true
}

// tags and deployment
deployFn.id = 'collateral:manager:deploy'
deployFn.tags = [
  'collateral',
  'collateral:manager',
  'collateral:manager:deploy',
]
deployFn.dependencies = ['teller-v2:deploy', 'collateral:escrow-beacon:deploy']
export default deployFn
