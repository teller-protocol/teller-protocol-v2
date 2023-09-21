import { DeployFunction } from 'hardhat-deploy/dist/types'

import { SUBTASK_GENERATE_ADD_EXTENSIONS_PROPOSAL_STEPS } from '../lender_commitment_forwarder/extensions/00_add_extensions'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('LenderCommitmentForwarder Downgrade: Proposing downgrade...')

  const tellerV2 = await hre.contracts.get('TellerV2')
  const marketRegistry = await hre.contracts.get('MarketRegistry')
  const lenderCommitmentForwarder = await hre.contracts.get(
    'LenderCommitmentForwarder'
  )

  const { protocolTimelock } = await hre.getNamedAccounts()

  const addExtensionProposalSteps = await hre.run(
    SUBTASK_GENERATE_ADD_EXTENSIONS_PROPOSAL_STEPS
  )

  await hre.defender.proposeBatchTimelock({
    title: 'Lender Commitment Forwarder Extension Upgrade',
    description: ` 
# LenderCommitmentForwarder_G1 (Extensions Upgrade)

* Downgrades the lender commitment forwarder to G1 
`,
    _steps: [
      {
        proxy: lenderCommitmentForwarder,
        implFactory: await hre.ethers.getContractFactory(
          'LenderCommitmentForwarder'
        ),

        opts: {
          unsafeAllow: ['constructor', 'state-variable-immutable'],
          constructorArgs: [
            await tellerV2.getAddress(),
            await marketRegistry.getAddress()
          ],
          call: {
            fn: 'initialize',
            args: [protocolTimelock]
          }
        }
      },
      ...addExtensionProposalSteps
    ]
  })
  await hre.run('oz:defender:save-proposed-steps', {
    steps: addExtensionProposalSteps
  })

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-forwarder:g1-downgrade'
deployFn.tags = [
  'proposal',
  'upgrade',
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:g1-downgrade'
]
deployFn.dependencies = [
  'market-registry:deploy',
  'teller-v2:deploy',
  'lender-commitment-forwarder:deploy',
  'lender-commitment-forwarder:extensions:deploy'
]
deployFn.skip = async (hre) => {
  return (
    !hre.network.live ||
    ![ 'sepolia'].includes(
      hre.network.name
    )
  )
}
export default deployFn
