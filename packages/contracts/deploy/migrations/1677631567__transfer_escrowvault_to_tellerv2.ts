import { DeployFunction } from 'hardhat-deploy/dist/types'
import { migrate } from 'helpers/migration-helpers'
import { EscrowVault } from 'types/typechain'

const deployFn: DeployFunction = migrate(
  __filename, // DO NOT CHANGE THIS LINE - it is used to determine the migration id
  async (hre) => {
    const tellerV2 = await hre.contracts.get('TellerV2')
    const escrowVault = await hre.contracts.get<EscrowVault>('EscrowVault')
    const { wait } = await escrowVault.transferOwnership(tellerV2.address)
    await wait(1)
  }
)

/**
 * List of deployment function tags. Listing a tag here means the migration script will not run
 * until the tag(s) specified are ran.
 */
deployFn.dependencies = ['teller-v2', 'escrow-vault']

export default deployFn
