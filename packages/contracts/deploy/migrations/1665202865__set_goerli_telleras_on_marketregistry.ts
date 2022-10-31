import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'
import { migrate } from 'helpers/migration-helpers'
import { MarketRegistry } from 'types/typechain'

import { getNetworkName } from '~~/config'

const deployFn: DeployFunction = migrate(
  __filename, // DO NOT CHANGE THIS LINE - it is used to determine the migration id
  async (hre) => {
    // only want to upgrade goerli
    if (getNetworkName(hre.network) !== 'goerli') return

    // Load existing contract
    const marketRegistry = await hre.contracts.get<MarketRegistry>(
      'MarketRegistry'
    )
    const tellerAS = await hre.contracts.get('TellerAS')

    hre.log('Setting TellerAS on MarketRegistry')
    hre.log(`tellerAS (current): ${await marketRegistry.tellerAS()}`, {
      indent: 1,
      star: true,
    })

    await deploy({
      name: 'MarketRegistry',
      contract: 'MarketRegistry__Goerli_TellerAS_Fix',
      args: [],
      proxy: {
        proxyContract: 'OpenZeppelinTransparentProxy',
        execute: {
          methodName: 'setTellerAS',
          args: [tellerAS.address],
        },
      },
      skipIfAlreadyDeployed: false, // ensure the upgrade is always executed
      hre,
    })

    hre.log(`tellerAS (new):     ${await marketRegistry.tellerAS()}`, {
      indent: 1,
      star: true,
    })
  }
)

/**
 * List of deployment function tags. Listing a tag here means the migration script will not run
 * until the tag(s) specified are ran.
 */
deployFn.dependencies = [
  /* deploy dependency tags go here */
]

export default deployFn
