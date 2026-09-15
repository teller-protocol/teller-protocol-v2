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
  const operator = process.env.HYPERNATIVE_OPERATOR_ADDRESS
  if (operator !== undefined && operator !== '' && operator !== ZERO) {
    if (!(await oracle.hasRole(OPERATOR_ROLE, operator))) {
      hre.log(`  Granting OPERATOR_ROLE to ${operator}...`)
      const tx = await oracle.grantRole(OPERATOR_ROLE, operator)
      await tx.wait(1)
      await logTxLink(hre, tx.hash)
    } else {
      hre.log(`  ✅  ${operator} already holds OPERATOR_ROLE`)
    }
  } else {
    hre.log(
      '  ⚠️  HYPERNATIVE_OPERATOR_ADDRESS is unset, so no operator can mark accounts risky.'
    )
    hre.log('      The oracle will be wired but will never block anyone.')
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
