import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('CommitmentRolloverLoan: Proposing upgrade...')

  const tellerV2 = await hre.contracts.get('TellerV2')
  const marketRegistry = await hre.contracts.get('MarketRegistry')
  const lenderCommitmentForwarder = await hre.contracts.get(
    'LenderCommitmentForwarder'
  )
  const commitmentRolloverLoan = await hre.contracts.get(
    'CommitmentRolloverLoan'
  )

  await hre.defender.proposeBatchTimelock(
    'Commitment Rollover Loan Upgrade',
    ` 
 
# CommitmentRolloverLoan

* Adds a new contract named CommitmentRolloverLoan.  This contract allows users to rollover an active loan into a new loan. 
`,
    [
      {
        proxy: commitmentRolloverLoan.address,
        implFactory: await hre.ethers.getContractFactory(
          'CommitmentRolloverLoan'
        ),

        opts: {
          unsafeAllow: ['constructor', 'state-variable-immutable'],
          constructorArgs: [tellerV2.address, lenderCommitmentForwarder.address]
        }
      }
    ]
  )

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'commitment-rollover-loan:deploy'
deployFn.tags = [
  'proposal',
  'upgrade',
  'commitment-rollover-loan',
  'commitment-rollover-loan:deploy'
]
deployFn.dependencies = [
  'teller-v2:deploy',
  'lender-commitment-forwarder:deploy'
]
deployFn.skip = async (hre) => {
  return false
}
export default deployFn
