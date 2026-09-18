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

  // upgradeProxy validates the new storage layout against the old one, and it
  // reads the old one out of OpenZeppelin's per-network manifest - the
  // .openzeppelin/*.json this repo does not keep. Without it the upgrade stops
  // at "Deployment at address 0x... is not registered", which is a missing
  // record rather than anything wrong with the proxy.
  //
  // forceImport writes that record from the implementation the proxy is
  // actually running, so the comparison has both sides. The manifest lives
  // only as long as the run, so this happens every time; it is idempotent, and
  // it is not a way around the layout check - upgradeProxy still performs it
  // against the imported layout.
  await hre.upgrades.forceImport(proxyAddress, implFactory, {
    kind: 'transparent',
    constructorArgs: [await tellerV2.getAddress(), swapRouter, quoter],
  } as any)

  const upgraded = await hre.upgrades.upgradeProxy(proxyAddress, implFactory, {
    unsafeAllow: ['constructor', 'state-variable-immutable'],
    constructorArgs: [await tellerV2.getAddress(), swapRouter, quoter],
  })
  await upgraded.waitForDeployment()

  const implementation = await hre.upgrades.erc1967.getImplementationAddress(
    proxyAddress
  )
  hre.log(`BorrowSwap:     ${proxyAddress}`, { star: false })
  hre.log(`Implementation: ${implementation}`, { star: false })
  hre.log(`Quoter:         ${quoter}`, { star: false })

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
