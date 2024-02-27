import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('MarketRegistryV2: Proposing upgrade...')

  //const tellerV2 = await hre.contracts.get('TellerV2')
  //const trustedForwarder = await hre.contracts.get('MetaForwarder')
  //const v2Calculations = await hre.deployments.get('V2Calculations')

  const marketRegistry = await hre.contracts.get('MarketRegistry')

  await hre.upgrades.proposeBatchTimelock({
    title: 'MarketRegistryV2: Upgrade for Market Registry V2',
    description: ` 
# MarketRegistryV2

* Modifies MarketRegistry so that it supports historical terms.
`,
    _steps: [
      {
        proxy: marketRegistry,
        implFactory: await hre.ethers.getContractFactory('MarketRegistry'),

        opts: {
          unsafeAllow: [
            'constructor',
            'state-variable-immutable',
            'external-library-linking'
          ],
          unsafeAllowRenames: true,
          unsafeSkipStorageCheck: true, //caution !
          constructorArgs: []
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
deployFn.id = 'market-registry:v2-upgrade'
deployFn.tags = ['proposal', 'upgrade', 'market-registry-v2-upgrade']
deployFn.dependencies = []
deployFn.skip = async (hre) => {
  return (
    !hre.network.live ||
    !['mainnet', 'arbitrum', 'goerli'].includes(hre.network.name)
  )
}
export default deployFn
