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
  const expectedOwner = namedAccounts.protocolAdminSafe
  const isOwner = currentOwner === expectedOwner

  hre.log(`   Current admin owner: ${currentOwner}`)
  hre.log(`  Expected admin owner: ${expectedOwner}`)
  hre.log('')

  let onlyRunOnce = isOwner

  if (!isOwner) {
    const canTransferOwnership = currentOwner === deployerAddress
    onlyRunOnce = canTransferOwnership
    if (canTransferOwnership) {
      hre.log('Transferring Default Proxy Admin ownership to multisig...')
      await hre.upgrades.admin.transferProxyAdminOwnership(
        expectedOwner,
        deployer
      )
      hre.log(
        `  ✅  Default Proxy Admin ownership transferred to multisig: ${expectedOwner}`
      )
    } else {
      hre.log(
        `  ❌  Cannot transfer Default Proxy Admin ownership... Must be run by deployer (${deployerAddress}).`
      )
    }
  } else {
    hre.log('  ✅  Default Proxy Admin ownership is correct.')
  }

  hre.log('')
  hre.log('=================================================================')

  return onlyRunOnce
}

// tags and deployment
deployFn.id = 'default-proxy-admin:transfer'
deployFn.tags = ['default-proxy-admin', 'default-proxy-admin:transfer']
deployFn.dependencies = ['teller-v2:deploy']
deployFn.runAtTheEnd = true
export default deployFn
