import { ContractByAddress } from '@tenderly/hardhat-tenderly/dist/tenderly/types'
import { subtask, task } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

interface VerifyContractsArgs {
  onlyEtherscan: boolean
  onlyTenderly: boolean
}

export const verifyContracts = async (
  args: VerifyContractsArgs,
  hre: HardhatRuntimeEnvironment
): Promise<void> => {
  const { network } = hre

  // Only continue on a live network
  if (!network.config.live)
    throw new Error('Must be on a live network to submit to Tenderly')

  let runArgs: VerifyRunArgs = {
    etherscan: true,
    tenderly: true,
  }
  if (args.onlyTenderly) runArgs = { tenderly: true }
  if (args.onlyEtherscan) runArgs = { etherscan: true }
  await hre.run('verify:run', runArgs)
}

interface VerifyRunArgs {
  etherscan?: boolean
  tenderly?: boolean
}

subtask('verify:run').setAction(
  async (
    args: VerifyRunArgs,
    hre: HardhatRuntimeEnvironment
  ): Promise<void> => {
    if (args.etherscan)
      await hre.run('etherscan-verify', { solcInput: true, sleep: true })
    if (args.tenderly) await hre.run('verify:tenderly')
  }
)

subtask(
  'verify:tenderly',
  'Verifies and pushes all deployed contracts to Tenderly'
).setAction(async (_, hre: HardhatRuntimeEnvironment): Promise<void> => {
  const { deployments, tenderly } = hre

  const networkId = await hre.getChainId()

  const allDeployments = await deployments.all().then((all) =>
    Object.entries(all).map<ContractByAddress>(([name, { address }]) => {
      return {
        address,
        display_name: name,
        network_id: networkId,
      }
    })
  )

  // await to make sure contracts are verified and pushed
  await tenderly.addToProject(...allDeployments)
})

task('verify', 'Verifies and pushes all deployed contracts to Tenderly')
  .addFlag('onlyEtherscan', 'Will only verify contracts on Etherscan')
  .addFlag('onlyTenderly', 'Will only verify contracts on Tenderly')
  .setAction(verifyContracts)
