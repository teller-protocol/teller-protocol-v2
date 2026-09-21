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

  if (expectedOwner === '0x0000000000000000000000000000000000000000') {
    hre.log('⚠️  protocolTimelock is zero address — skipping proxy admin ownership transfer. Run deploy again after setting protocolTimelock.')
    hre.log('')
    hre.log('=================================================================')
    // `false`, so hardhat-deploy does not record this migration id. `true`
    // records it, and a recorded id never runs again - which turned the "run
    // deploy again after setting protocolTimelock" above into something that
    // could not happen. Pass 1 skips here with the timelock still unset,
    // writes the id, and pass 2 finds the work already marked done.
    //
    // That is how Arc ended up with a deployed-and-wired Safe and timelock
    // that own nothing, and a ProxyAdmin - admin of sixteen proxies, TellerV2
    // among them - still held by the deployer EOA. Robinhood has the same
    // shape. Chains already carrying the stale record need the
    // `default-proxy-admin:transfer` line removed from their
    // deployments/<network>/.migrations.json before pass 2 can pick it up;
    // this fix only stops it happening to the next chain.
    return false
  }

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
export default deployFn
