import { DeployFunction } from 'hardhat-deploy/dist/types'
import { logTxLink } from 'helpers/logTxLink'

const deployFn: DeployFunction = async (hre) => {
  hre.log('=================================================================')
  hre.log('')
  hre.log('ApeChain: Transferring beacon + proxy admin ownership to Timelock')
  hre.log('')

  const { deployer, protocolTimelock } = await hre.getNamedAccounts()

  // --- Transfer beacon ownership ---

  const beaconNames = [
    'CollateralEscrowBeacon',
    'LenderCommitmentGroupBeaconV2',
  ]

  for (const beaconName of beaconNames) {
    const beacon = await hre.contracts.get(beaconName)
    const currentOwner = await beacon.owner()

    if (currentOwner === protocolTimelock) {
      hre.log(
        `  ✅  ${beaconName} ownership is already set to Timelock`
      )
    } else if (currentOwner === deployer) {
      hre.log(`  Transferring ${beaconName} ownership to Timelock...`)
      const tx = await beacon.transferOwnership(protocolTimelock)
      await tx.wait(1)
      hre.log(
        `  ✅  ${beaconName} ownership transferred to Timelock (${protocolTimelock})`
      )
      await logTxLink(hre, tx.hash)
    } else {
      hre.log(
        `  ⚠️  ${beaconName} is owned by ${currentOwner} (not deployer). Skipping.`
      )
    }
  }

  // --- Transfer Default Proxy Admin ownership ---

  hre.log('')
  hre.log('  Checking Default Proxy Admin ownership...')

  const defaultProxyAdmin = await hre.upgrades.admin.getInstance()
  const proxyAdminOwner = await defaultProxyAdmin.owner()

  if (proxyAdminOwner === protocolTimelock) {
    hre.log('  ✅  Default Proxy Admin ownership is already set to Timelock')
  } else if (proxyAdminOwner === deployer) {
    hre.log('  Transferring Default Proxy Admin ownership to Timelock...')
    const signer = await hre.getNamedSigner('deployer')
    await hre.upgrades.admin.transferProxyAdminOwnership(
      protocolTimelock,
      signer
    )
    hre.log(
      `  ✅  Default Proxy Admin ownership transferred to Timelock (${protocolTimelock})`
    )
  } else {
    hre.log(
      `  ⚠️  Default Proxy Admin is owned by ${proxyAdminOwner} (not deployer). Skipping.`
    )
  }

  hre.log('')
  hre.log('done.')
  hre.log('=================================================================')

  return true
}

// tags and deployment
deployFn.id = 'apechain:transfer-timelock-ownership'
deployFn.tags = ['apechain', 'apechain:transfer-timelock-ownership']
deployFn.dependencies = [
  'collateral:escrow-beacon:deploy',
  'lender-commitment-group-beacon-v2:deploy',
  'teller-v2:deploy',
]

deployFn.skip = async (hre) => {
  return !hre.network.live || hre.network.name !== 'apechain'
}
export default deployFn
