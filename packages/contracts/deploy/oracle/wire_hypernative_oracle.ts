import fs from 'fs'
import path from 'path'

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

/**
 * Where OracleProtectionManager keeps the oracle address:
 * `keccak256("eip1967.hypernative.oracle") - 1`. There is no getter for it,
 * and the difference matters here - with the slot at zero the manager fails
 * open and `oracleRegister` reverts on a call into address(0), so the
 * registrations below are worth attempting only once setOracle has run.
 */
const ORACLE_SLOT =
  '0xfa373e1ee49299afe249e16436ea939a0edb26953bec7179d544957654b3ba1f'

/**
 * Protocol contracts that call an oracle-protected function for a borrower,
 * and therefore have to be registered with the oracle themselves.
 *
 * `isOracleApprovedAllowEOA` waves a borrower through when they are the
 * transaction's origin, which is why a plain wallet never needs any of this.
 * Loop, Short and rollover do not work that way: the borrower calls BorrowSwap
 * or SwapRolloverLoan, and *that* contract calls the forwarder. The check then
 * sees a sender that is not tx.origin and has code, so it asks the oracle how
 * long that sender has been registered - and `isTimeExceeded` does not return
 * false for an account it has never seen, it reverts with "Account not
 * registered".
 *
 * So an unregistered BorrowSwap is not a contract that gets refused, it is
 * every Loop and every Short on the chain reverting, with an error that reads
 * as though the borrower's own wallet were the problem. Base registered these
 * at some point and has worked ever since; Robinhood launched without them and
 * nothing in the bootstrap would have caught it, because the failure only
 * appears once the oracle is wired, which happens at the very end.
 *
 * Registering a contract records a timestamp and nothing else. It grants no
 * role and no exemption: the contract still has to clear the same threshold
 * every registered account does, and Hypernative can still blacklist it.
 */
const ORACLE_PROTECTED_CALLERS = [
  'BorrowSwap',
  'SwapRolloverLoan',
  'LoanReferralForwarder',
  'LoanReferralForwarderV2',
  'FlashRolloverLoan',
]

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('Wiring the Hypernative oracle')
  hre.log('')

  const { deployer, protocolOwnerSafe } = await hre.getNamedAccounts()
  const ZERO = '0x0000000000000000000000000000000000000000'

  // Calls the Safe has to make itself, collected as a Transaction Builder
  // batch. Everything above this point the deployer can do on its own.
  const safeBatch: Array<{
    to: string
    value: string
    data: string
    contractMethod: null
    contractInputsValues: null
  }> = []

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

  // Register the protocol's own contracts, now that the forwarder can.
  //
  // Only worth trying once the oracle is actually wired: before that
  // `oracleRegister` calls into address(0) and reverts, and on a first deploy
  // setOracle is still sitting in the Safe batch this script writes at the
  // end. Re-running afterwards picks them up.
  const wiredOracle = `0x${(
    await hre.ethers.provider.getStorage(forwarderAddress, ORACLE_SLOT)
  ).slice(-40)}`
  if (wiredOracle === ZERO) {
    hre.log('')
    hre.log(
      '  ⚠️  No oracle set on the forwarder yet, so protocol contracts cannot be'
    )
    hre.log(
      '      registered. Execute the Safe batch below, then run this again.'
    )
  } else {
    hre.log('')
    hre.log('  Registering the protocol contracts that borrow on a user\'s behalf')
    for (const name of ORACLE_PROTECTED_CALLERS) {
      const contract = await hre.deployments.getOrNull(name)
      if (!contract) continue
      const address = contract.address

      // isTimeExceeded is onlyConsumer, so ask it as the forwarder. It answers
      // true or false for an account it knows and reverts for one it does not,
      // which is exactly the question being asked.
      let registered: boolean
      try {
        await oracle.isTimeExceeded.staticCall(address, {
          from: forwarderAddress,
        })
        registered = true
      } catch {
        registered = false
      }

      if (registered) {
        hre.log(`  ✅  ${name} is already registered`, { star: false })
        continue
      }

      const tx = await forwarder.oracleRegister(address)
      await tx.wait(1)
      await logTxLink(hre, tx.hash)
      hre.log(`  Registered ${name} at ${address}`, { star: false })
    }
    hre.log(
      '      They are approved once the oracle threshold has passed - two minutes by default.'
    )
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
      hre.log(`  Queueing addPauser(${operator}) for the Safe...`)
      safeBatch.push({
        to: pausingManagerAddress,
        value: '0',
        data: pausingManager.interface.encodeFunctionData('addPauser', [
          operator,
        ]),
        contractMethod: null,
        contractInputsValues: null,
      })
    }
  }

  hre.log('')
  hre.log(`  Queueing setOracle(${oracleAddress}) for the Safe...`)
  safeBatch.push({
    to: forwarderAddress,
    value: '0',
    data: forwarder.interface.encodeFunctionData('setOracle', [oracleAddress]),
    contractMethod: null,
    contractInputsValues: null,
  })

  // Written out rather than proposed to the Safe Transaction Service.
  //
  // That service only accepts a proposal signed by an owner or a registered
  // delegate, and the deployer is neither — on Robinhood the Safe has five
  // owners, none of them the deploy key, and no delegates. So proposeCall
  // could never have worked here however it was configured: it had nothing
  // to sign with. A file an owner imports needs no key at all.
  //
  // Registering the deployer as a delegate would restore the automated path,
  // and needs one signature from an owner.
  const outPath = path.join(
    'deployments',
    hre.network.name,
    'hypernative-safe-batch.json'
  )
  fs.writeFileSync(
    outPath,
    `${JSON.stringify(
      {
        version: '1.0',
        chainId: String(hre.network.config.chainId),
        createdAt: Date.now(),
        meta: {
          name: `Enable Hypernative on ${hre.network.name}`,
          description:
            'Grants the pauser role to the Hypernative response wallet, and points SmartCommitmentForwarder at the HypernativeOracle.',
          txBuilderVersion: '1.16.5',
        },
        transactions: safeBatch,
      },
      null,
      2
    )}\n`
  )
  hre.log('')
  hre.log(`  ✅  Safe batch written to ${outPath}`)
  hre.log(
    '      Import it in the Safe UI: Apps -> Transaction Builder -> Load.'
  )
  hre.log('      Nothing takes effect until the signers execute it.')
  for (const tx of safeBatch) {
    hre.log(`        to ${tx.to}  data ${tx.data}`)
  }

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
