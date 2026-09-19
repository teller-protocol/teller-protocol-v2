import { DeployFunction } from 'hardhat-deploy/dist/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

import { get_ecosystem_contract_address } from '../../helpers/ecosystem-contracts-lookup'

/**
 * Point BorrowSwap at the quoter that is deployed now, rather than the one it
 * was constructed with.
 *
 * BorrowSwap holds its quoter in an immutable, so a chain that redeploys the
 * quoter keeps calling the old one until the implementation behind the proxy
 * is replaced. That is not cosmetic: on a chain running this repo's vendored
 * view-quoter, the pre-fix build reverted with Panic(0x11) on any pool priced
 * high enough to need FullMath's 512-bit path, so `quoteExactInput` answered
 * for some pools and not others. The frontend reads that function for the
 * amount a Loop or a Short receives, so those pools showed 0.00.
 *
 * Only the quote is affected. `UNISWAP_QUOTER` is read in `quoteExactInput`
 * and nowhere else - the swap itself goes through the router - so no loan or
 * position depends on which quoter is bound.
 *
 * This upgrades in place rather than deploying a second BorrowSwap: the proxy
 * address is what the frontends hold and what borrowers have added as an
 * extension, and a new address would silently strand both.
 */

const resolveVenue = async (hre: HardhatRuntimeEnvironment) => {
  const swapRouter = get_ecosystem_contract_address(
    hre.network.name,
    'uniswapV3SwapRouter'
  )?.trim()
  const quoter = (await hre.deployments.getOrNull('Quoter'))?.address
  return { swapRouter: swapRouter || undefined, quoter }
}

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('BorrowSwap: rebinding to the currently deployed quoter...')

  const tellerV2 = await hre.contracts.get('TellerV2')
  const borrowSwap = await hre.contracts.get('BorrowSwap')
  const { swapRouter, quoter } = await resolveVenue(hre)

  // skip() has established both, but an upgrade that passed a zero address
  // would bake it into an immutable that cannot be corrected without another
  // upgrade.
  if (!swapRouter || !quoter) {
    throw new Error(
      `BorrowSwap rebind on ${hre.network.name}: swapRouter=${swapRouter} quoter=${quoter}`
    )
  }

  const proxyAddress = await borrowSwap.getAddress()
  const implFactory = await hre.ethers.getContractFactory('BorrowSwap')

  const live = borrowSwap as any

  // upgradeProxy validates the new storage layout against the old one, and it
  // reads the old one out of OpenZeppelin's per-network manifest, keyed by the
  // address the proxy currently points at. Where that record is missing the
  // upgrade stops at "Deployment at address 0x... is not registered", which is
  // a missing record rather than anything wrong with the proxy, and
  // forceImport writes it from the implementation the proxy is running.
  //
  // So try the upgrade first and only import when it says the record is
  // absent. Importing unconditionally breaks the chains that need this most:
  // this repo *does* commit .openzeppelin/*.json, so on a chain whose manifest
  // is already there, forceImport recomputes the version hash from the
  // constructor args it is handed, finds nothing under that new key, and files
  // the already-recorded implementation address a second time - which
  // OpenZeppelin refuses as "The following deployment clashes with an existing
  // one at 0x...". Arc failed exactly there, with a manifest that had the
  // proxy and its implementation recorded correctly all along.
  //
  // When the import is needed, its constructor args have to be the ones the
  // *current* implementation was built with, read off the contract itself.
  // Importing it under the args we are upgrading *to* records an
  // implementation that answers to those args already, and upgradeProxy then
  // reuses it and changes nothing: the run reports success, the proxy still
  // points at the old implementation, and the old quoter is still bound.
  const upgrade = async () =>
    hre.upgrades.upgradeProxy(proxyAddress, implFactory, {
      unsafeAllow: ['constructor', 'state-variable-immutable'],
      constructorArgs: [await tellerV2.getAddress(), swapRouter, quoter],
    })

  let upgraded
  try {
    upgraded = await upgrade()
  } catch (err) {
    if (!/is not registered/.test((err as Error)?.message ?? '')) throw err

    hre.log(
      'BorrowSwap: no manifest record for the live implementation, importing it...'
    )
    await hre.upgrades.forceImport(proxyAddress, implFactory, {
      kind: 'transparent',
      constructorArgs: [
        await live.TELLER_V2(),
        await live.UNISWAP_SWAP_ROUTER(),
        await live.UNISWAP_QUOTER(),
      ],
      unsafeAllow: ['constructor', 'state-variable-immutable'],
    } as any)
    upgraded = await upgrade()
  }
  await upgraded.waitForDeployment()

  // Assert the thing this script exists to do. upgradeProxy reports success
  // whether or not it replaced anything - reusing a matching implementation is
  // a legitimate outcome for it - so without this the only signal that the
  // rebind did nothing is an address in a log line that nobody reads.
  //
  // Polled rather than read once, because the read and the write do not have to
  // reach the same machine. The RPC endpoints this deploys through are load
  // balancers over several backends, and `waitForDeployment` resolves on the
  // implementation's own deploy, not on the admin's upgrade being visible to
  // whichever backend answers next. Arc failed exactly here: the upgrade landed
  // in block 21643658 and succeeded, the check ran 900ms later against a
  // backend that had not caught up, and a rebind that had worked reported
  // itself as "changed nothing" - taking the artifacts down with it, since a
  // crashed run pushes none.
  //
  // So a stale answer is retried and only a settled one is believed. This
  // weakens nothing: the assertion still fails, and fails loudly, for a rebind
  // that genuinely did not happen - it just waits long enough to tell the two
  // apart.
  const settledQuoter = async (): Promise<string> => {
    let bound = ''
    for (let attempt = 0; attempt < 20; attempt++) {
      bound = (await live.UNISWAP_QUOTER()) as string
      if (bound.toLowerCase() === quoter.toLowerCase()) return bound
      await new Promise((resolve) => setTimeout(resolve, 1500))
    }
    return bound
  }

  const boundAfter = await settledQuoter()
  const implementation = await hre.upgrades.erc1967.getImplementationAddress(
    proxyAddress
  )
  hre.log(`BorrowSwap:     ${proxyAddress}`, { star: false })
  hre.log(`Implementation: ${implementation}`, { star: false })
  hre.log(`Quoter:         ${quoter}`, { star: false })

  if (boundAfter.toLowerCase() !== quoter.toLowerCase()) {
    throw new Error(
      `BorrowSwap rebind on ${hre.network.name} changed nothing: still bound to ` +
        `${boundAfter}, expected ${quoter}, after 30s of polling. The proxy is ` +
        `at ${proxyAddress}, implementation ${implementation}.`
    )
  }

  // Keep the artifact honest about which implementation is live, so the next
  // run's idempotency check and every consumer of the deployment read the
  // same thing the chain does.
  const existing = await hre.deployments.get('BorrowSwap')
  await hre.deployments.save('BorrowSwap', {
    ...existing,
    address: proxyAddress,
    implementation,
    abi: JSON.parse(implFactory.interface.formatJson()),
  })

  hre.log('')
  hre.log('----------')

  return true
}

deployFn.id = 'lender-commitment-forwarder:extensions:borrow-swap:rebind-quoter'
deployFn.tags = [
  'upgrade',
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:extensions',
  'lender-commitment-forwarder:extensions:borrow-swap',
  'lender-commitment-forwarder:extensions:borrow-swap:rebind-quoter',
]
deployFn.dependencies = [
  'teller-v2:deploy',
  'uniswapv3-quoter:deploy',
  'lender-commitment-forwarder:extensions:borrow-swap:deploy',
]

deployFn.skip = async (hre) => {
  if (!hre.network.live) return true

  // Nothing to rebind where either side is absent - a chain pointing at a
  // canonical Uniswap quoter has no `Quoter` deployment of its own.
  const borrowSwap = await hre.deployments.getOrNull('BorrowSwap')
  const { swapRouter, quoter } = await resolveVenue(hre)
  if (!borrowSwap || !swapRouter || !quoter) return true

  // Idempotent: skip once the live implementation already points at it.
  const live = (await hre.contracts.get('BorrowSwap')) as any
  const bound: string = await live.UNISWAP_QUOTER()
  if (bound.toLowerCase() === quoter.toLowerCase()) return true

  // An upgrade is only signable where the deployer still owns the proxy
  // admin. Where it has been handed to a Safe or a timelock this has to go
  // through a proposal instead, so say so rather than failing mid-deploy.
  const adminAddress = await hre.upgrades.erc1967.getAdminAddress(
    borrowSwap.address
  )
  const admin = (await hre.ethers.getContractAt(
    ['function owner() view returns (address)'],
    adminAddress
  )) as any
  const owner: string = await admin.owner()
  const deployer = await (await hre.getNamedSigner('deployer')).getAddress()
  if (owner.toLowerCase() !== deployer.toLowerCase()) {
    hre.log(
      `BorrowSwap rebind on ${hre.network.name}: proxy admin is owned by ${owner}, ` +
        `not the deployer - propose this upgrade through that owner instead.`
    )
    return true
  }

  return false
}

export default deployFn
