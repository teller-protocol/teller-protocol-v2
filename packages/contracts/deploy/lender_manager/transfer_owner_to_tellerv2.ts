import { getCurrentChainConfig } from '@nomicfoundation/hardhat-verify/dist/src/chain-config'
import { DeployFunction } from 'hardhat-deploy/dist/types'
import { HARDHAT_NETWORK_NAME } from 'hardhat/plugins'
import { LenderManager } from 'types/typechain'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('Lender Manager: Transferring Ownership to TellerV2...', {
    nl: false,
  })

  const tellerV2 = await hre.contracts.get('TellerV2')
  const lenderManager = await hre.contracts.get<LenderManager>('LenderManager')

  const tx = await lenderManager.transferOwnership(tellerV2.address)
  await tx.wait(1)
  let txLink = tx.hash
  if (hre.network.name !== HARDHAT_NETWORK_NAME) {
    const chainConfig = await getCurrentChainConfig(
      hre.network,
      hre.config.etherscan.customChains
    )
    txLink = `${chainConfig.urls.browserURL}/tx/${tx.hash}`
  }

  hre.log('done.')
  hre.log(`${txLink}`, { star: true, indent: 1 })
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'lender-manager:transfer-ownership'
deployFn.tags = ['lender-manager', 'lender-manager:transfer-ownership']
deployFn.dependencies = ['teller-v2', 'lender-manager:deploy']
export default deployFn
