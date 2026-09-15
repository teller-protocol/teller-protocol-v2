import { DeployFunction } from 'hardhat-deploy/dist/types'
import { logTxLink } from 'helpers/logTxLink'

/**
 * Turns the Hypernative firewall on for a chain.
 *
 * Deploying HypernativeOracle does nothing by itself. OracleProtectionManager
 * fails open —
 *
 *     if (oracleAddress == address(0)) { return true; }
 *
 * — so until SmartCommitmentForwarder is pointed at an oracle, every caller is
 * approved. Robinhood sat in exactly that state: oracle deployed, slot zero,
 * nothing filtered.
 *
 * One setOracle covers the whole protocol surface that has protection. The
 * pools (LenderCommitmentGroup_Pool_V2/V3/_Smart) inherit OracleProtectedChild,
 * whose immutable ORACLE_MANAGER is the forwarder, so they ask it rather than
 * holding their own oracle address.
 *
 * Order matters in the role handling below. The oracle's DEFAULT_ADMIN_ROLE
 * starts on the deployer, because mock_hypernative_oracle.ts passes the
 * deployer as _admin. Leaving it there means the deploy key can whitelist or
 * blacklist anyone, and on Robinhood that key was printed into a job log. So
 * admin moves to the Safe — but only after confirming the Safe actually holds
 * it, because renouncing first would leave the oracle permanently unadministered.
 */
/**
 * Hypernative's response wallet per chain — the address their monitoring
 * signs blacklist/whitelist transactions from. It needs gas on that chain.
 */
const HYPERNATIVE_OPERATORS: Record<string, string> = {
  robinhood: '0xa6af91a354e5acc23e0de58500828f40803c60aa',
}

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('Wiring the Hypernative oracle')
  hre.log('')

  const { deployer, protocolOwnerSafe } = await hre.getNamedAccounts()
  const ZERO = '0x0000000000000000000000000000000000000000'

  if (protocolOwnerSafe === ZERO) {
    hre.log('  ⚠️  protocolOwnerSafe is unset. Skipping.')
    return true
  }

  const oracle = await hre.contracts.get('HypernativeOracle')
  const forwarder = await hre.contracts.get('SmartCommitmentForwarder')
  const oracleAddress = await oracle.getAddress()
  const forwarderAddress = await forwarder.getAddress()

  const ADMIN_ROLE = await oracle.DEFAULT_ADMIN_ROLE()
  const OPERATOR_ROLE = await oracle.OPERATOR_ROLE()
  const CONSUMER_ROLE = await oracle.CONSUMER_ROLE()

  // The forwarder calls oracle.register()/registerStrict(), both onlyConsumer.
  // Without this every oracleRegister reverts and nothing can be registered.
  if (!(await oracle.hasRole(CONSUMER_ROLE, forwarderAddress))) {
    hre.log('  Granting CONSUMER_ROLE to SmartCommitmentForwarder...')
    const tx = await oracle.grantRole(CONSUMER_ROLE, forwarderAddress)
    await tx.wait(1)
    await logTxLink(hre, tx.hash)
  } else {
    hre.log('  ✅  SmartCommitmentForwarder already holds CONSUMER_ROLE')
  }

  // Hypernative's own address: the one that calls blacklist()/whitelist() as
  // their monitoring decides. Without it the oracle is wired but nobody can
  // ever mark an account risky, which is protection in name only.
  //
  // Per chain, because Hypernative issues a separate response wallet for each.
  // Recorded here rather than left to an environment variable so that wiring a
  // chain does not depend on someone remembering to set one — a missing
  // operator produces a firewall that looks installed and blocks nobody.
  const operator =
    process.env.HYPERNATIVE_OPERATOR_ADDRESS ??
    HYPERNATIVE_OPERATORS[hre.network.name]
  if (operator !== undefined && operator !== '' && operator !== ZERO) {
    if (!(await oracle.hasRole(OPERATOR_ROLE, operator))) {
      hre.log(`  Granting OPERATOR_ROLE to ${operator}...`)
      hre.log(
        '  (it signs its own blacklist calls, so it needs gas on this chain)'
      )
      const tx = await oracle.grantRole(OPERATOR_ROLE, operator)
      await tx.wait(1)
      await logTxLink(hre, tx.hash)
    } else {
      hre.log(`  ✅  ${operator} already holds OPERATOR_ROLE`)
    }
  } else {
    hre.log(
      `  ⚠️  No Hypernative operator known for ${hre.network.name}, so no one can mark accounts risky.`
    )
    hre.log(
      '      The oracle would be wired and block nobody. Add the chain to'
    )
    hre.log('      HYPERNATIVE_OPERATORS, or set HYPERNATIVE_OPERATOR_ADDRESS.')
  }

  // Admin to the Safe, then off the deployer — in that order.
  if (!(await oracle.hasRole(ADMIN_ROLE, protocolOwnerSafe))) {
    hre.log('  Granting DEFAULT_ADMIN_ROLE to the Safe...')
    const tx = await oracle.grantRole(ADMIN_ROLE, protocolOwnerSafe)
    await tx.wait(1)
    await logTxLink(hre, tx.hash)
  } else {
    hre.log('  ✅  Safe already holds DEFAULT_ADMIN_ROLE')
  }

  const safeIsAdmin = await oracle.hasRole(ADMIN_ROLE, protocolOwnerSafe)
  const deployerIsAdmin = await oracle.hasRole(ADMIN_ROLE, deployer)
  if (safeIsAdmin && deployerIsAdmin) {
    hre.log('  Renouncing the deployer DEFAULT_ADMIN_ROLE...')
    const tx = await oracle.renounceRole(ADMIN_ROLE, deployer)
    await tx.wait(1)
    await logTxLink(hre, tx.hash)
  } else if (!safeIsAdmin) {
    hre.log(
      '  ⚠️  Safe is not admin, so the deployer keeps the role rather than leaving the oracle unadministered.'
    )
  }

  // setOracle is onlyProtocolOwner and the forwarder is Safe-owned by now, so
  // this is a proposal rather than a transaction.
  // The pause path, which is what Hypernative's automated response actually
  // uses. Their notification channels call ProtocolPausingManager.pauseProtocol
  // and SmartCommitmentForwarder.pause, and both check the pauser role — so
  // without this the response fires and reverts, which looks like protection
  // right up until the moment it matters.
  //
  // addPauser is onlyOwner and the manager is Safe-owned, so it is proposed.
  if (operator !== undefined && operator !== '' && operator !== ZERO) {
    const pausingManager = await hre.contracts.get('ProtocolPausingManager')
    const pausingManagerAddress = await pausingManager.getAddress()
    if (await pausingManager.isPauser(operator)) {
      hre.log(`  ✅  ${operator} is already a pauser`)
    } else {
      hre.log(`  Proposing addPauser(${operator}) on the Safe...`)
      await hre.upgrades.proposeCall(
        pausingManagerAddress,
        pausingManager,
        'addPauser',
        [operator],
        "Let Hypernative's automated response pause the protocol",
        `Grants the pauser role to ${operator}, Hypernative's response wallet on ` +
          `${hre.network.name}. Their pause channels call pauseProtocol() here and ` +
          'pause() on SmartCommitmentForwarder; both revert without it.'
      )
      hre.log('  ✅  Proposed.')
    }
  }

  hre.log('')
  hre.log(`  Proposing setOracle(${oracleAddress}) on the Safe...`)
  await hre.upgrades.proposeCall(
    forwarderAddress,
    forwarder,
    'setOracle',
    [oracleAddress],
    'Enable the Hypernative firewall',
    `Points SmartCommitmentForwarder at HypernativeOracle ${oracleAddress}. ` +
      'Until this executes the oracle check fails open and every caller is approved.'
  )
  hre.log('  ✅  Proposed. It takes effect once the Safe signers execute it.')

  hre.log('')
  hre.log('done.')
  hre.log('----------')

  return true
}

deployFn.id = 'hypernative-oracle:wire'
deployFn.tags = ['hypernative-oracle:wire']
deployFn.dependencies = [
  'hypernative-oracle-mock:deploy',
  'smart-commitment-forwarder:deploy',
  'protocol-pausing-manager:deploy',
]
deployFn.skip = async (hre) =>
  !hre.network.live ||
  ![
    'polygon',
    'arbitrum',
    'base',
    'mainnet',
    'bsc',
    'apechain',
    'xdc',
    'robinhood',
  ].includes(hre.network.name)

export default deployFn
