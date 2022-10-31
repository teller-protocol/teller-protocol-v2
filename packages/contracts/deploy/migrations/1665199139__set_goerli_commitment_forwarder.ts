import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'
import { migrate } from 'helpers/migration-helpers'
import { TellerV2 } from 'types/typechain'

import { getNetworkName } from '~~/config'

const deployFn: DeployFunction = migrate(
  __filename, // DO NOT CHANGE THIS LINE - it is used to determine the migration id
  async (hre) => {
    // only want to upgrade goerli
    if (getNetworkName(hre.network) !== 'goerli') return

    // Load existing contract
    const tellerV2 = await hre.contracts.get<TellerV2>('TellerV2')
    const lenderCommitmentForwarder = await hre.contracts.get(
      'LenderCommitmentForwarder'
    )
    const trustedForwarder = await hre.contracts.get('MetaForwarder')

    hre.log('Setting LenderCommitmentForwarder on TellerV2')
    hre.log(
      `lenderCommitmentForwarder (current): ${await tellerV2.lenderCommitmentForwarder()}`,
      { indent: 1, star: true }
    )

    await deploy({
      name: 'TellerV2',
      contract: 'TellerV2__Goerli_Commitment_Forwarder_Fix',
      args: [trustedForwarder.address],
      proxy: {
        proxyContract: 'OpenZeppelinTransparentProxy',
        execute: {
          methodName: 'setLenderCommitmentForwarder',
          args: [lenderCommitmentForwarder.address],
        },
      },
      skipIfAlreadyDeployed: false, // ensure the upgrade is always executed
      hre,
    })

    hre.log(
      `lenderCommitmentForwarder (new):     ${await tellerV2.lenderCommitmentForwarder()}`,
      { indent: 1, star: true }
    )
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
