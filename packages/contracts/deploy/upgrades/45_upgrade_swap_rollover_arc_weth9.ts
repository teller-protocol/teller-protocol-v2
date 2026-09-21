import { DeployFunction } from 'hardhat-deploy/dist/types'

import {
  get_ecosystem_contract_address,
  get_swap_rollover_weth9_address,
} from '../../helpers/ecosystem-contracts-lookup'

/**
 * Re-deploys the SwapRolloverLoan implementation on Arc with WETH9 = address(0).
 *
 * The implementation code is unchanged - WETH9 is an immutable, so the only way
 * to correct it is a new implementation behind the same proxy.
 *
 * Arc's live deployment was constructed with WETH9 =
 * 0x3600000000000000000000000000000000000000, the chain's USDC predeploy, which
 * is the address the swap paths legitimately use. The rollover does not use it
 * that way: PeripheryPayments.pay() reads WETH9 as "the token that means wrapped
 * native coin", and when the token it owes the pool matches it, it wraps native
 * coin rather than transferring the ERC-20 the contract already holds.
 *
 * On Arc those are the same balance. USDC is the gas asset, so the contract's
 * native balance is never short of what it owes, the wrap branch is always
 * taken, and `deposit{value: ...}()` sends value to a precompile - which Arc
 * rejects outright. Every rollover of a USDC loan reverted with "Blocked
 * address" after burning the whole gas limit; observed on
 * 0xef16a9081cf362e4d1c23924106917dba9ad11706ba587acf11040cf31598253.
 *
 * With address(0) the comparison can never match, pay() takes the safeTransfer
 * branch, and the rollover pays the pool the way every other chain does.
 */
const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('SwapRolloverLoan (Arc): Proposing WETH9 correction upgrade...')

  const swapRolloverLoan = await hre.contracts.get('SwapRolloverLoan')
  const tellerV2 = await hre.contracts.get('TellerV2')

  const uniswapV3FactoryAddress = get_ecosystem_contract_address(
    hre.network.name,
    'uniswapV3Factory'
  )
  const weth9Address = get_swap_rollover_weth9_address(hre.network.name)

  await hre.upgrades.proposeBatchTimelock({
    title: 'Swap Rollover Loan WETH9 Correction (Arc)',
    description: `
# SwapRolloverLoan WETH9 correction (Arc)

* Re-deploys the implementation with WETH9 = address(0). No source change.
* Arc's native gas asset is USDC and 0x3600...0000 is that same balance as an
  ERC-20, so PeripheryPayments.pay() always took its wrap-native branch and
  called deposit{value} on the predeploy. Arc rejects value sent to a
  precompile, so every rollover reverted with "Blocked address".
* address(0) can never equal the token being paid, so pay() takes the
  safeTransfer branch. Nothing on Arc wraps or unwraps native coin, so the
  branch is not needed for anything else.
`,
    _steps: [
      {
        proxy: swapRolloverLoan,
        implFactory: await hre.ethers.getContractFactory('SwapRolloverLoan'),

        opts: {
          unsafeAllow: ['constructor', 'state-variable-immutable'],
          constructorArgs: [
            await tellerV2.getAddress(),
            uniswapV3FactoryAddress,
            weth9Address,
          ],
        },
      },
    ],
  })

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id =
  'lender-commitment-forwarder:extensions:flash-swap-rollover:weth9-upgrade-arc'
deployFn.tags = [
  'proposal',
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
  return hre.network.name !== 'arc'
}
export default deployFn
