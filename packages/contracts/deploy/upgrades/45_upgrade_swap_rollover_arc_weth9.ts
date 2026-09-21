import { DeployFunction } from 'hardhat-deploy/dist/types'

import {
  get_ecosystem_contract_address,
  get_swap_rollover_weth9_address,
} from '../../helpers/ecosystem-contracts-lookup'

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

/**
 * Re-deploys the SwapRolloverLoan implementation on Arc with WETH9 = address(0).
 *
 * The implementation source is unchanged. WETH9 is an immutable, so the only
 * way to correct it is a new implementation behind the same proxy.
 *
 * Arc's live deployment was constructed with WETH9 =
 * 0x3600000000000000000000000000000000000000, the chain's USDC predeploy, which
 * is right for swap paths and wrong for this. Uniswap's PeripheryPayments.pay()
 * reads WETH9 as "the token that means wrapped native coin", and when the token
 * it owes the pool matches, it wraps native coin instead of transferring the
 * ERC-20 the contract is already holding.
 *
 * On Arc those are the same balance. USDC is the gas asset, so the contract's
 * native balance is never short of what it owes, the wrap branch is always
 * taken, and `deposit{value: ...}()` sends value to the predeploy. Arc rejects
 * that at the protocol level. Confirmed against the live chain rather than
 * reasoned about - an eth_call to 0x3600...0000 carrying value comes back
 * "Blocked address", the same call with no value comes back a plain "execution
 * reverted", and the borrower's rollover
 * 0xef16a9081cf362e4d1c23924106917dba9ad11706ba587acf11040cf31598253 reverted
 * with "Blocked address" after burning 1,707,529 gas.
 *
 * With address(0) the comparison can never match, pay() takes the safeTransfer
 * branch, and the rollover pays the pool the way every other chain does.
 *
 * Why this upgrades directly instead of proposing a timelock batch, which is
 * what the BSC and ApeChain rollover upgrades beside it do:
 *
 * Arc's ProxyAdmin (0xf4Fed0F9361ee5E1a7abBe343b0FeaF843281964, admin of this
 * proxy and of TellerV2 alike) is still owned by the deployer. The Safe and the
 * TimelockController both exist on Arc and are wired to each other, but neither
 * owns the ProxyAdmin: `default_proxy_admin.ts` recorded its migration during
 * deploy pass 1 while skipping on a zero-address `protocolTimelock`, so pass 2
 * could never pick it up. A timelock batch would therefore deploy an
 * implementation, file two Safe proposals, and revert on `onlyOwner` when
 * anyone tried to execute them.
 *
 * So this follows 42_rebind_borrow_swap_quoter.ts, which upgrades through the
 * deployer and has already done so successfully on this chain. When Arc's
 * ownership hand-off is completed, later upgrades should move back to the
 * timelock path and this script needs no second run.
 */
const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('SwapRolloverLoan (Arc): correcting WETH9...')

  const swapRolloverLoan = await hre.contracts.get('SwapRolloverLoan')
  const tellerV2 = await hre.contracts.get('TellerV2')

  const uniswapV3FactoryAddress = get_ecosystem_contract_address(
    hre.network.name,
    'uniswapV3Factory'
  )
  const weth9Address = get_swap_rollover_weth9_address(hre.network.name)

  if (weth9Address !== ZERO_ADDRESS) {
    throw new Error(
      `SwapRolloverLoan WETH9 correction expects address(0) on ${hre.network.name}, ` +
        `got ${weth9Address}. Check get_swap_rollover_weth9_address.`
    )
  }

  const proxyAddress = await swapRolloverLoan.getAddress()
  const live = swapRolloverLoan as any

  // Idempotent: a proxy already pointing at a corrected implementation is a
  // finished job, not a reason to deploy another one.
  const weth9Before = (await live.WETH9()) as string
  if (weth9Before.toLowerCase() === ZERO_ADDRESS) {
    hre.log('  ✅  WETH9 is already address(0); nothing to do.')
    hre.log('')
    hre.log('----------')
    return true
  }
  hre.log(`  Current WETH9: ${weth9Before}`)

  const implFactory = await hre.ethers.getContractFactory('SwapRolloverLoan')
  const constructorArgs = [
    await tellerV2.getAddress(),
    uniswapV3FactoryAddress,
    weth9Address,
  ]

  // Same manifest handling as the BorrowSwap rebind, and for the same reason:
  // upgradeProxy validates the new storage layout against the old one out of
  // OpenZeppelin's per-network manifest, and stops at "is not registered" when
  // that record is missing. Import only on that error - importing
  // unconditionally files a second record for an implementation already in the
  // committed manifest, which OpenZeppelin refuses as a clash.
  //
  // The import has to describe the implementation the proxy is running *now*,
  // read off the contract, not the one being upgraded to. Importing it under
  // the new args would record an implementation that already answers to them,
  // and upgradeProxy would then reuse it and change nothing while reporting
  // success.
  const upgrade = async () =>
    hre.upgrades.upgradeProxy(proxyAddress, implFactory, {
      unsafeAllow: ['constructor', 'state-variable-immutable'],
      constructorArgs,
    })

  let upgraded
  try {
    upgraded = await upgrade()
  } catch (err) {
    if (!/is not registered/.test((err as Error)?.message ?? '')) throw err

    hre.log(
      'SwapRolloverLoan: no manifest record for the live implementation, importing it...'
    )
    await hre.upgrades.forceImport(proxyAddress, implFactory, {
      kind: 'transparent',
      constructorArgs: [
        await live.TELLER_V2(),
        await live.factory(),
        weth9Before,
      ],
      unsafeAllow: ['constructor', 'state-variable-immutable'],
    } as any)
    upgraded = await upgrade()
  }
  await upgraded.waitForDeployment()

  // Assert the thing this script exists to do. upgradeProxy reports success
  // whether or not it replaced anything, so without this a run that changed
  // nothing looks identical to one that worked.
  //
  // Polled rather than read once: these RPC endpoints are load balancers over
  // several backends, and `waitForDeployment` resolves on the implementation's
  // own deploy, not on the admin's upgrade being visible to whichever backend
  // answers next. The BorrowSwap rebind was reported as a no-op on this exact
  // chain for that reason, having actually worked.
  const settledWeth9 = async (): Promise<string> => {
    let bound = ''
    for (let attempt = 0; attempt < 20; attempt++) {
      bound = (await live.WETH9()) as string
      if (bound.toLowerCase() === ZERO_ADDRESS) return bound
      await new Promise((resolve) => setTimeout(resolve, 1500))
    }
    return bound
  }

  const weth9After = await settledWeth9()
  const implementation = await hre.upgrades.erc1967.getImplementationAddress(
    proxyAddress
  )
  hre.log(`SwapRolloverLoan: ${proxyAddress}`, { star: false })
  hre.log(`Implementation:   ${implementation}`, { star: false })
  hre.log(`WETH9:            ${weth9After}`, { star: false })

  if (weth9After.toLowerCase() !== ZERO_ADDRESS) {
    throw new Error(
      `SwapRolloverLoan WETH9 correction on ${hre.network.name} changed nothing: ` +
        `still ${weth9After}, expected ${ZERO_ADDRESS}, after 30s of polling. The ` +
        `proxy is at ${proxyAddress}, implementation ${implementation}.`
    )
  }

  // Keep the artifact honest about which implementation is live, so the next
  // run's idempotency check and every consumer of the deployment read the same
  // thing the chain does.
  const existing = await hre.deployments.get('SwapRolloverLoan')
  await hre.deployments.save('SwapRolloverLoan', {
    ...existing,
    address: proxyAddress,
    implementation,
    abi: JSON.parse(implFactory.interface.formatJson()),
  })

  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id =
  'lender-commitment-forwarder:extensions:flash-swap-rollover:weth9-upgrade-arc'
deployFn.tags = [
  'upgrade',
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:extensions',
  'lender-commitment-forwarder:extensions:flash-swap-rollover',
  'lender-commitment-forwarder:extensions:flash-swap-rollover:weth9-upgrade-arc',
]
deployFn.dependencies = [
  'teller-v2:deploy',
  'lender-commitment-forwarder:staging:deploy',
  'lender-commitment-forwarder:extensions:flash-swap-rollover:deploy',
]
deployFn.skip = async (hre) => {
  if (!hre.network.live) return true
  return hre.network.name !== 'arc'
}
export default deployFn
