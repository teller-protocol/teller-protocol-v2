import { DeployFunction } from 'hardhat-deploy/dist/types'
import { migrate } from 'helpers/migration-helpers'
import { LenderManager, TellerV2 } from 'types/typechain'

const deployFn: DeployFunction = migrate(
  __filename, // DO NOT CHANGE THIS LINE - it is used to determine the migration id
  async (hre) => {
    const tellerV2 = await hre.contracts.get<TellerV2>('TellerV2')
    const lenderManager = await hre.contracts.get<LenderManager>(
      'LenderManager'
    )

    if ((await lenderManager.owner()) !== tellerV2.address)
      await lenderManager.transferOwnership(tellerV2.address)

    if ((await tellerV2.lenderManager()) === hre.ethers.constants.AddressZero)
      await tellerV2.setLenderManager(lenderManager.address)
  }
)

/**
 * List of deployment function tags. Listing a tag here means the migration script will not run
 * until the tag(s) specified are ran.
 */
deployFn.dependencies = ['teller-v2', 'lender-manager']

export default deployFn
