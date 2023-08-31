import { LenderCommitmentForwarder } from 'generated/typechain/contracts/LenderCommitmentForwarder'
import { DeployFunction } from 'hardhat-deploy/dist/types'
import { subtask } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { BatchProposalStep } from 'helpers/hre-extensions'

const deployFn: DeployFunction = async (hre) => {
  const steps = await hre.run(SUBTASK_GENERATE_ADD_EXTENSIONS_PROPOSAL_STEPS)
  if (steps.length) {
    await hre.defender.proposeBatchTimelock({
      title: 'Add Extension to LenderCommitmentForwarder',
      description: ` 
  # Adds an extension to the LenderCommitmentForwarder
  `,
      _steps: steps,
    })
  }
}

// tags and deployment
deployFn.id = 'lender-commitment-forwarder:extensions:add-extensions'
deployFn.tags = [
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:extensions',
  'lender-commitment-forwarder:extensions:add-extensions',
]
deployFn.dependencies = [
  'lender-commitment-forwarder:g2-upgrade',
  // This waits for all extensions to be deployed before creating a proposal to add them to the forwarder
  'lender-commitment-forwarder:extensions:deploy',
]

export default deployFn

export const SUBTASK_GENERATE_ADD_EXTENSIONS_PROPOSAL_STEPS =
  'lender-commitment-forwarder:extensions:add:generate-proposal-steps'
subtask(
  SUBTASK_GENERATE_ADD_EXTENSIONS_PROPOSAL_STEPS,
  'Generates a list of batch proposal steps to add extensions to the LenderCommitmentForwarder'
).setAction(
  async (
    args: any,
    hre: HardhatRuntimeEnvironment
  ): Promise<BatchProposalStep[]> => {
    const lenderCommitmentForwarder =
      await hre.contracts.get<LenderCommitmentForwarder>(
        'LenderCommitmentForwarder'
      )
    const lenderCommitmentForwarderG2Factory =
      await hre.ethers.getContractFactory('LenderCommitmentForwarder_G2')

    const extensions = await Promise.all([
      // Add extensions here
      hre.contracts.get('FlashRolloverLoan'),
    ])
    const steps: BatchProposalStep[] = []
    for (const extension of extensions) {
      if (await lenderCommitmentForwarder.isTrustedForwarder(extension))
        continue

      steps.push({
        contractAddress: await lenderCommitmentForwarder.getAddress(),
        contractImplementation: lenderCommitmentForwarderG2Factory,
        callFn: 'addExtension',
        callArgs: [await extension.getAddress()],
      })
    }
    return steps
  }
)
