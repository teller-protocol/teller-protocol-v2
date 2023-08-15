import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')
  const lenderCommitmentForwarder = await hre.contracts.get(
    'LenderCommitmentForwarder'
  )
  const commitmentRolloverLoan = await hre.deployProxy(
    'CommitmentRolloverLoan',
    {
      unsafeAllow: ['constructor', 'state-variable-immutable'],
      constructorArgs: [tellerV2.address, lenderCommitmentForwarder.address]
    }
  )

  return true
}

// tags and deployment
deployFn.id = 'commitment-rollover-loan:deploy'
deployFn.tags = ['commitment-rollover-loan', 'commitment-rollover-loan:deploy']
deployFn.dependencies = [
  'teller-v2:deploy',
  'lender-commitment-forwarder:deploy'
]
export default deployFn
