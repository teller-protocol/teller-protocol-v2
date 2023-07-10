import { getCurrentChainConfig } from '@nomicfoundation/hardhat-verify/dist/src/chain-config'
import { DeployFunction } from 'hardhat-deploy/dist/types'
import { HARDHAT_NETWORK_NAME } from 'hardhat/plugins'
import { TellerV2 } from 'types/typechain'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('TellerV2: Transferring Ownership to Safe Multisig')
  hre.log('')

  const { deployer, protocolOwnerSafe } = await hre.getNamedAccounts()
  const tellerV2 = await hre.contracts.get<TellerV2>('TellerV2')
  const currentOwner = await tellerV2.owner()

  if (deployer === currentOwner) {
    const tx = await tellerV2.transferOwnership(protocolOwnerSafe)

    hre.log(
      `  ✅  TellerV2 ownership transferred to Safe Multisig (${protocolOwnerSafe})`
    )

    if (hre.network.name !== HARDHAT_NETWORK_NAME) {
      const chainConfig = await getCurrentChainConfig(
        hre.network,
        hre.config.etherscan.customChains
      )
      hre.log(`${chainConfig.urls.browserURL}/tx/${tx.hash}`, {
        star: true,
        indent: 1,
      })
    }
  } else if (protocolOwnerSafe === currentOwner) {
    hre.log('  ✅  TellerV2 ownership is already set to the Safe Multisig')
  } else {
    throw new Error(
      `  ❌  Cannot transfer TellerV2 ownership... Must be run by current owner (${currentOwner}).`
    )
  }

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'teller-v2:transfer-ownership-to-safe'
deployFn.tags = ['teller-v2', 'teller-v2:transfer-ownership-to-safe']
deployFn.dependencies = ['teller-v2:init']
export default deployFn
