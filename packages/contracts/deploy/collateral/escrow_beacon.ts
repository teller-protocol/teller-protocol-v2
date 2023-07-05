import { DeployFunction } from 'hardhat-deploy/dist/types'
import { UpgradeableBeacon } from 'types/typechain'

const deployFn: DeployFunction = async (hre) => {
  const collateralEscrowBeacon = await hre.deployBeacon<UpgradeableBeacon>(
    'CollateralEscrowV1',
    {
      customName: 'CollateralEscrowBeacon',
    }
  )

  const { protocolProxyAdminTimelock } = await hre.getNamedAccounts()
  hre.log('Transferring ownership of CollateralEscrowBeacon to Gnosis Safe...')
  await collateralEscrowBeacon.transferOwnership(protocolProxyAdminTimelock)
  hre.log('done.')

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
