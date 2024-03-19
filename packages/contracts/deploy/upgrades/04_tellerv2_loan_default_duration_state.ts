import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('TellerV2: Proposing upgrade...')

  const tellerV2 = await hre.contracts.get('TellerV2')
  const trustedForwarder = await hre.contracts.get('MetaForwarder')
  const v2Calculations = await hre.deployments.get('V2Calculations')

  await hre.upgrades.proposeBatchTimelock({
    title: 'TellerV2: Fix Loan Defaulted State',
    description: ` 
# TellerV2

* Fixes unintended functionality where the loan is not able to be liquidated when default duration was set to zero.
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
          unsafeAllow: [
            'constructor',
            'state-variable-immutable',
            'external-library-linking',
          ],
          constructorArgs: [await trustedForwarder.getAddress()],
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
deployFn.id = 'teller-v2:loan-defaulted-state-upgrade'
deployFn.tags = [
  'proposal',
  'upgrade',
  'teller-v2',
  'teller-v2:loan-defaulted-state-upgrade',
]
deployFn.dependencies = ['teller-v2:deploy']
deployFn.skip = async (hre) => {
  return (
    !hre.network.live ||
    !['mainnet',   'goerli'].includes(hre.network.name)
  )
}
export default deployFn
