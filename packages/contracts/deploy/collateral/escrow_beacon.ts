import { DeployFunction } from 'hardhat-deploy/dist/types'
import { UpgradeableBeacon } from 'types/typechain'

const deployFn: DeployFunction = async (hre) => {
  const collateralEscrowBeacon = await hre.deployBeacon<UpgradeableBeacon>(
    'CollateralEscrowV1',
    {
      customName: 'CollateralEscrowBeacon',
    }
  )

    //is this necessary ? 
  const { protocolTimelock } = await hre.getNamedAccounts()
  if (protocolTimelock === '0x0000000000000000000000000000000000000000') {
    // Do not tell anyone to "run deploy again" here: this script records its
    // id whether or not the transfer happened, and a recorded id never runs
    // again, so a second pass cannot pick it up. That is how Arc and Robinhood
    // both left this beacon on the deployer EOA. The transfer now has its own
    // script, which is not blocked by this record:
    // deploy/upgrades/46_transfer_timelock_ownership.ts
    hre.log('⚠️  protocolTimelock is zero address — skipping escrow beacon ownership transfer. Run the `protocol:transfer-timelock-ownership` tag once the timelock is set.')
  } else {
    hre.log('Transferring ownership of CollateralEscrowBeacon to Protocol Timelock...')
    await collateralEscrowBeacon.transferOwnership(protocolTimelock)
    hre.log('done.')
  }

  //ultimately, the owner becomes the collateral manager 
  //isnt this just an implementation?

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
