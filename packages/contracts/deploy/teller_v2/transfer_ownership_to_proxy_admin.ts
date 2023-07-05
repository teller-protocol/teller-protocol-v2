import { getCurrentChainConfig } from '@nomicfoundation/hardhat-verify/dist/src/chain-config'
import { DeployFunction } from 'hardhat-deploy/dist/types'
import { HARDHAT_NETWORK_NAME } from 'hardhat/plugins'
import { TellerV2 } from 'types/typechain'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('TellerV2: Transferring ownership to Proxy Admin contract...', {
    nl: false,
  })

  const tellerV2 = await hre.contracts.get<TellerV2>('TellerV2')
  const adminAddress = await hre.upgrades.erc1967.getAdminAddress(
    tellerV2.address
  )

  const tx = await tellerV2.transferOwnership(adminAddress)

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
deployFn.id = 'teller-v2:transfer-ownership-to-proxy-admin'
deployFn.tags = ['teller-v2', 'teller-v2:transfer-ownership-to-proxy-admin']
deployFn.dependencies = ['teller-v2:init']
export default deployFn
