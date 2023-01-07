import { DeployFunction } from 'hardhat-deploy/dist/types'
import { migrate } from 'helpers/migration-helpers'
import { CollateralManager, TellerV2 } from 'types/typechain'

const deployFn: DeployFunction = migrate(
  __filename, // DO NOT CHANGE THIS LINE - it is used to determine the migration id
  async (hre) => {
    const tellerV2 = await hre.contracts.get<TellerV2>('TellerV2')
    const collateralManager = await hre.contracts.get<CollateralManager>(
      'CollateralManager'
    )

    if ((await collateralManager.owner()) !== tellerV2.address)
      await collateralManager.transferOwnership(tellerV2.address)

    if (
      (await tellerV2.collateralManager()) === hre.ethers.constants.AddressZero
    )
      await tellerV2.setCollateralManager(collateralManager.address)

    if (await tellerV2.paused()) await tellerV2.unpauseProtocol()
  }
)

/**
 * List of deployment function tags. Listing a tag here means the migration script will not run
 * until the tag(s) specified are ran.
 */
deployFn.dependencies = ['teller-v2', 'collateral-manager']

export default deployFn
