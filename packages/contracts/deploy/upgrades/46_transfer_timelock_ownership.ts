import { DeployFunction } from 'hardhat-deploy/dist/types'
import { logTxLink } from 'helpers/logTxLink'

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

/**
 * Hands the beacons, the group factory and the ProxyAdmin to the protocol
 * timelock, on any chain where the deployer is still holding them.
 *
 * This exists because the transfers it performs live inside the `:deploy`
 * scripts that create those contracts, and on a two-pass chain launch that is
 * the wrong place for them. Pass 1 runs with `protocolTimelock` unset, the
 * transfer is skipped, and the script records its migration id anyway - so
 * pass 2, which is the pass that has the timelock, never runs it again. The
 * instruction those scripts print, "run deploy again after setting
 * protocolTimelock", cannot be followed.
 *
 * That is not hypothetical. It is how Arc and Robinhood both ended up with
 * every proxy, both beacons and the group factory owned by a single deployer
 * EOA with no code, while their 2-of-5 Safes and TimelockControllers sat
 * deployed, correctly wired to each other, and owning nothing.
 *
 * Clearing those stale records would work, but it also re-runs `deployBeacon`
 * against whatever contracts ref the run pins - shipping a new implementation
 * when all that was wanted was to move an owner. So the transfer gets its own
 * script with its own id instead. It deploys nothing, it is idempotent, and it
 * is not blocked by any record already written.
 *
 * Every action is guarded on the current owner:
 *   - already the timelock  -> reported and left alone
 *   - the deployer          -> transferred
 *   - anyone else           -> reported and left alone, never forced
 *
 * so a chain that is already correct is a no-op, and a chain that was handed
 * to something other than the deployer is never quietly overwritten.
 */
const deployFn: DeployFunction = async (hre) => {
  hre.log('=================================================================')
  hre.log('')
  hre.log(`${hre.network.name}: handing ownership to the protocol timelock`)
  hre.log('')

  const { deployer, protocolTimelock } = await hre.getNamedAccounts()

  const lower = (a: string) => (a ?? '').toLowerCase()
  const isTimelock = (a: string) => lower(a) === lower(protocolTimelock)
  const isDeployer = (a: string) => lower(a) === lower(deployer)

  // The Ownable contracts. Absent from a chain's deployments is not a failure:
  // not every chain has every one of these, and asking for one that was never
  // deployed should skip rather than take the run down.
  const ownableNames = [
    'CollateralEscrowBeacon',
    'LenderCommitmentGroupBeaconV2',
    'LenderCommitmentGroupFactory_V2',
  ]

  for (const name of ownableNames) {
    let contract
    try {
      contract = await hre.contracts.get(name)
    } catch {
      hre.log(`  –   ${name} is not deployed on this chain. Skipping.`)
      continue
    }

    const currentOwner: string = await contract.owner()

    if (isTimelock(currentOwner)) {
      hre.log(`  ✅  ${name} is already owned by the timelock`)
    } else if (isDeployer(currentOwner)) {
      hre.log(`  →   transferring ${name} to the timelock...`)
      const tx = await contract.transferOwnership(protocolTimelock)
      await tx.wait(1)
      hre.log(`  ✅  ${name} transferred to ${protocolTimelock}`)
      await logTxLink(hre, tx.hash)
    } else {
      hre.log(
        `  ⚠️  ${name} is owned by ${currentOwner}, which is neither the ` +
          `deployer nor the timelock. Left alone.`
      )
    }
  }

  // The ProxyAdmin, which is the one that matters most: it is the admin of
  // every transparent proxy on the chain, TellerV2 included.
  hre.log('')
  const defaultProxyAdmin = await hre.upgrades.admin.getInstance()
  const proxyAdminOwner: string = await defaultProxyAdmin.owner()

  if (isTimelock(proxyAdminOwner)) {
    hre.log('  ✅  Default Proxy Admin is already owned by the timelock')
  } else if (isDeployer(proxyAdminOwner)) {
    hre.log('  →   transferring Default Proxy Admin to the timelock...')
    const signer = await hre.getNamedSigner('deployer')
    await hre.upgrades.admin.transferProxyAdminOwnership(
      protocolTimelock,
      signer
    )
    hre.log(`  ✅  Default Proxy Admin transferred to ${protocolTimelock}`)
  } else {
    hre.log(
      `  ⚠️  Default Proxy Admin is owned by ${proxyAdminOwner}, which is ` +
        `neither the deployer nor the timelock. Left alone.`
    )
  }

  hre.log('')
  hre.log('done.')
  hre.log('=================================================================')

  return true
}

// tags and deployment
deployFn.id = 'protocol:transfer-timelock-ownership'
deployFn.tags = ['protocol', 'protocol:transfer-timelock-ownership']
deployFn.dependencies = ['teller-v2:deploy']

deployFn.skip = async (hre) => {
  if (!hre.network.live) return true

  // Nothing to hand over to. Deliberately `false` is not returned here the way
  // it is in the scripts this replaces: skipping on an unset timelock is the
  // one case where recording the id would be wrong, and hardhat-deploy only
  // records what actually ran.
  const { protocolTimelock } = await hre.getNamedAccounts()
  if (!protocolTimelock || protocolTimelock === ZERO_ADDRESS) {
    hre.log(
      `protocolTimelock is unset on ${hre.network.name} - nothing to transfer ` +
        `ownership to. Set <NETWORK>_TIMELOCK_ADDRESS and run again.`
    )
    return true
  }

  return false
}
export default deployFn
