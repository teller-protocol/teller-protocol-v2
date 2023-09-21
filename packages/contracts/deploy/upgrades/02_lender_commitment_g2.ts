import { DeployFunction } from 'hardhat-deploy/dist/types'

import { SUBTASK_GENERATE_ADD_EXTENSIONS_PROPOSAL_STEPS } from '../lender_commitment_forwarder/extensions/00_add_extensions'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('LenderCommitmentForwarder V2: Proposing upgrade...')

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
# LenderCommitmentForwarder_G2 (Extensions Upgrade)

* Upgrades the lender commitment forwarder so that trusted extensions can specify a specific recipient
* Adds a new function acceptCommitmentWithRecipient which is explicitly used with these new types.
* Adds ${addExtensionProposalSteps.length} new extensions to the forwarder
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
            await marketRegistry.getAddress(),
          ],
          call: {
            fn: 'initialize',
            args: [protocolTimelock],
          },
        },
      },
      ...addExtensionProposalSteps,
    ],
  })
  await hre.run('oz:defender:save-proposed-steps', {
    steps: addExtensionProposalSteps,
  })

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-forwarder:g2-upgrade'
deployFn.tags = [
  'proposal',
  'upgrade',
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:g2-upgrade',
]
deployFn.dependencies = [
  'market-registry:deploy',
  'teller-v2:deploy',
  'lender-commitment-forwarder:deploy',
  'lender-commitment-forwarder:extensions:deploy',
]
deployFn.skip = async (hre) => {
  return true //always skip for now

  /* return (
    !hre.network.live ||
    !['mainnet', 'polygon', 'arbitrum', 'goerli', 'sepolia'].includes(
      hre.network.name
    )
  )*/
}
export default deployFn
