import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('Lender Groups Factory: Proposing upgrade...')

  const lenderCommitmentGroupsFactory = await hre.contracts.get('LenderCommitmentGroupFactory_V2')
  
 
  await hre.upgrades.proposeBatchTimelock({
    title: 'LenderGroupsFactory: Deposit Transfer ',
    description: ` 
# LenderGroupsFactory

* Adds support for upgraded lending pools.
`,
    _steps: [
      {
        proxy: lenderCommitmentGroupsFactory,
        implFactory: await hre.ethers.getContractFactory('LenderCommitmentGroupFactory_V2', {
        }),

        opts: {
         // unsafeSkipStorageCheck: true, 
          unsafeAllow: [
            'constructor',
            'state-variable-immutable',
            'external-library-linking',
          ],
          constructorArgs:  [],
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
deployFn.id = 'lender-commitment-group-factory:deposit-transfer'
deployFn.tags = [
  'proposal',
  'upgrade',
  'teller-v2',
  'lender-commitment-group-factory:deposit-transfer',
]
deployFn.dependencies = ['lender-commitment-group-factory:deploy']
deployFn.skip = async (hre) => {
  return !hre.network.live || !['goerli', 'polygon'].includes(hre.network.name)
}
export default deployFn
