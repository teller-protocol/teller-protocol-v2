import { ContractByName } from '@tenderly/hardhat-tenderly/dist/tenderly/types'
import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

export const verifyContracts = async (
  args: null,
  hre: HardhatRuntimeEnvironment
): Promise<void> => {
  const { network } = hre

  // Only continue on a live network
  if (!network.config.live)
    throw new Error('Must be on a live network to submit to Tenderly')

  // Verify contracts on Etherscan
  await hre.run('etherscan-verify', { solcInput: true, sleep: true })

  // Save and verify contracts on Tenderly
  await tenderlyVerify(hre)
}

const tenderlyVerify = async (
  hre: HardhatRuntimeEnvironment
): Promise<void> => {
  const { deployments, tenderly } = hre

  const allDeployments = await deployments.all().then((all) =>
    Object.entries(all).map<ContractByName>(
      ([name, { address, libraries }]) => ({
        name,
        address,
        libraries,
      })
    )
  )

  // await to make sure contracts are verified and pushed
  await tenderly.verify(...allDeployments)
}

task(
  'verify',
  'Verifies and pushes all deployed contracts to Tenderly'
).setAction(verifyContracts)
