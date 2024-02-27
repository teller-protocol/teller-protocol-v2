import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('TellerV2: Proposing upgrade...')

  const tellerV2 = await hre.contracts.get('TellerV2')
  const trustedForwarder = await hre.contracts.get('MetaForwarder')
  const v2Calculations = await hre.deployments.get('V2Calculations')

  const collateralManagerV2 = await hre.contracts.get('CollateralManagerV2')

  await hre.upgrades.proposeBatchTimelock({
    title: 'TellerV2: Upgrade for Collateral Manager V2',
    description: ` 
# TellerV2

* Modifies Teller V2 so that it supports the Collateral Manager V2.
`,
    _steps: [
      {
        proxy: tellerV2,
        implFactory: await hre.ethers.getContractFactory('TellerV2', {
          libraries: {
            V2Calculations: v2Calculations.address
          }
        }),

        opts: {
          unsafeAllow: [
            'constructor',
            'state-variable-immutable',
            'external-library-linking'
          ],
          unsafeAllowRenames: true,
          constructorArgs: [await trustedForwarder.getAddress()],

          call: {
            fn: 'setCollateralManagerV2',
            args: [await collateralManagerV2.getAddress()]
          }
        }
      }
    ]
  })

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'teller-v2:collateral-manager-v2-upgrade'
deployFn.tags = [
  'proposal',
  'upgrade',
  'teller-v2',
  'teller-v2:collateral-manager-v2-upgrade'
]
deployFn.dependencies = ['teller-v2:deploy', 'collateral:manager-v2:deploy']
deployFn.skip = async (hre) => {
  return (
    !hre.network.live ||
    !['mainnet', 'arbitrum', 'goerli'].includes(hre.network.name)
  )
}
export default deployFn
