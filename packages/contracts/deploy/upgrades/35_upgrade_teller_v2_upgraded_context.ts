import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('TellerV2: Proposing upgrade...')

  const tellerV2 = await hre.contracts.get('TellerV2')
  const metaForwarder = await hre.contracts.get('MetaForwarder')
  const v2Calculations = await hre.deployments.get('V2Calculations')

 

  await hre.upgrades.proposeBatchTimelock({
    title: 'TellerV2: Protocol Trusted Forwarder ',
    description: ` 
# TellerV2

* Adds support for improved trusted forwarder.
`,
    _steps: [
      {
        proxy: tellerV2,
        implFactory: await hre.ethers.getContractFactory('TellerV2', {
          libraries: {
            V2Calculations: v2Calculations.address,
          },
        }),

        opts: {
          unsafeSkipStorageCheck: true, 
          unsafeAllow: [
            'constructor',
            'state-variable-immutable',
            'external-library-linking',
          ],
          constructorArgs: [await metaForwarder.getAddress()],
        },
      },
    ],
  })

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'teller-v2:context-forwarding-upgrade'
deployFn.tags = [
  'proposal',
  'upgrade',
  'teller-v2',
  'teller-v2:context-forwarding-upgrade',
]
deployFn.dependencies = ['teller-v2:deploy']
deployFn.skip = async (hre) => {
  return !hre.network.live || !['goerli', 'polygon'].includes(hre.network.name)
}
export default deployFn
