import { ethers } from 'hardhat'
import { DeployFunction } from 'hardhat-deploy/dist/types'
import { migrate } from 'helpers/migration-helpers'
import { TellerV2 } from 'types/typechain'

const deployFn: DeployFunction = migrate(
  __filename, // DO NOT CHANGE THIS LINE - it is used to determine the migration id
  async (hre) => {
    const tellerV2 = await hre.contracts.get<TellerV2>('TellerV2')

    let lenderManagerAddress
    try {
      lenderManagerAddress = await tellerV2.lenderManager()
    } catch (e) {}

    if (
      !lenderManagerAddress ||
      lenderManagerAddress === ethers.constants.AddressZero
    ) {
      const lenderManager = await hre.contracts.get('LenderManager')

      const deployer = await hre.getNamedSigner('deployer')
      const { wait } = await tellerV2
        .connect(deployer)
        .setLenderManager(lenderManager.address)
      await wait(1)
    }
  }
)

/**
 * List of deployment function tags. Listing a tag here means the migration script will not run
 * until the tag(s) specified are ran.
 */
deployFn.dependencies = ['teller-v2', 'lender-manager']

export default deployFn
