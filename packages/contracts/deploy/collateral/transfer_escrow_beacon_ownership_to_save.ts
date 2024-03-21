import { DeployFunction } from 'hardhat-deploy/dist/types'
import { UpgradeableBeacon } from 'types/typechain'

const deployFn: DeployFunction = async (hre) => {
    const collateralEscrowBeacon = await hre.contracts.get(
        'CollateralEscrowBeacon'
      )



  const { protocolTimelock } = await hre.getNamedAccounts()
  hre.log('Transferring ownership of CollateralEscrowBeacon to Gnosis Safe...')
  await collateralEscrowBeacon.transferOwnership(protocolTimelock)
  hre.log('done.')

  return true
}

// tags and deployment
deployFn.id = 'collateral:escrow-beacon:transfer-ownership-to-gnosis-safe'
deployFn.tags = [
  'collateral',
  'collateral:escrow-beacon',
  'collateral:escrow-beacon:deploy',
]
deployFn.dependencies = ['collateral:escrow-beacon:deploy']
deployFn.skip = async (hre) => {
    return (
      !hre.network.live ||
      !['mainnet', 'polygon', 'arbitrum', 'base'].includes(hre.network.name)
    )
  }
export default deployFn
