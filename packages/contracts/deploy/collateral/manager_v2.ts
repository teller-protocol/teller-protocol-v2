import { DeployFunction } from 'hardhat-deploy/dist/types'
import { CollateralManagerV2 } from 'types/typechain'

const deployFn: DeployFunction = async (hre) => {
  const collateralEscrowBeacon = await hre.contracts.get(
    'CollateralEscrowBeacon'
  )
  const tellerV2 = await hre.contracts.get('TellerV2')

  const collateralManagerV2 = await hre.deployProxy('CollateralManagerV2', {
    initArgs: [tellerV2] //for initializer
  })

  return true
}

// tags and deployment
deployFn.id = 'collateral:manager-v2:deploy'
deployFn.tags = [
  'collateral',
  'collateral:manager-v2',
  'collateral:manager-v2:deploy'
]
deployFn.dependencies = ['teller-v2:deploy']
export default deployFn
