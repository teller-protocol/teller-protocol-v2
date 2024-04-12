import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('=================================================================')
  hre.log('')
  hre.log('  🤔  Checking Default Proxy Admin ownership...')
  hre.log('')

  const defaultProxyAdmin = await hre.upgrades.admin.getInstance()
  const currentOwner = await defaultProxyAdmin.owner()

  const deployer = await hre.getNamedSigner('deployer')
  const deployerAddress = await deployer.getAddress()

  const namedAccounts = await hre.getNamedAccounts()
  const expectedOwner = namedAccounts.protocolTimelock
  const isOwner = currentOwner === expectedOwner

  hre.log(`   Current admin owner: ${currentOwner}`)
  hre.log(`  Expected admin owner: ${expectedOwner}`)
  hre.log('')

  if (!isOwner) {
    const canTransferOwnership = currentOwner === deployerAddress
    if (canTransferOwnership) {
      hre.log('Transferring Default Proxy Admin ownership to Timelock...')
      await hre.upgrades.admin.transferProxyAdminOwnership(
        expectedOwner,
        deployer
      )
      hre.log(
        `  ✅  Default Proxy Admin ownership transferred to Timelock: ${expectedOwner}`
      )
    } else {
      throw new Error(
        `  ❌  Cannot transfer Default Proxy Admin ownership... Must be run by current owner (${currentOwner}).`
      )
    }
  } else {
    hre.log('  ✅  Default Proxy Admin ownership is correct.')
  }

  hre.log('')
  hre.log('=================================================================')

  return true
}

// tags and deployment
deployFn.id = 'default-proxy-admin:transfer'
deployFn.tags = ['default-proxy-admin', 'default-proxy-admin:transfer']
deployFn.dependencies = ['teller-v2:deploy']
deployFn.runAtTheEnd = true

deployFn.skip = async (hre) => {
  
  return (
    !hre.network.live ||
    !['mainnet', 'polygon', 'arbitrum', 'goerli','base', 'sepolia'].includes(
      hre.network.name
    )
  )
}


export default deployFn
