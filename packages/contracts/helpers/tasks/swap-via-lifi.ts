import { task, types } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

/**
 * Swaps one ERC-20 for another from the deployer wallet, routed by LI.FI.
 *
 * WHY THIS EXISTS. Activating a LenderCommitmentGroup pool needs the owner's
 * first deposit in that pool's *principal*, and an inverse pool's principal is
 * the volatile asset rather than the chain's stablecoin. On Arc that is ARGUS,
 * which the deployer has no way to acquire - the protocol can price a token it
 * cannot buy. Every other funding route on this repo assumes a human at a
 * bridge UI, which is fine for a chain launch and useless for a pool that needs
 * $2 of a memecoin to open.
 *
 * WHY LI.FI RATHER THAN THE POOL'S OWN ROUTER. The oracle route and the trade
 * route are not the same problem. UniswapPricingLibraryV2 reads one pool at one
 * fee tier because it needs a TWAP it can reason about; a trade wants whatever
 * venue is deepest right now, and on a chain days old that is not a thing to
 * hardcode. LI.FI also returns a signed-off `toAmountMin`, so the slippage
 * bound comes from the quote rather than from arithmetic in this file.
 *
 * WHAT IT REFUSES TO DO. This is a swap task, not a bridge task, and the
 * difference matters because the same endpoint serves both: a bridge route
 * would send funds to another chain and return here having "succeeded". So the
 * quote is rejected unless both sides name this network's chain id, and the
 * transaction is rejected unless it does too.
 *
 * It also will not spend a chain's gas out from under itself. On Arc the gas
 * token and the principal are the same balance seen two ways - 18-decimal
 * native, 6-decimal ERC-20 - so a swap of the ERC-20 is a swap of the gas, and
 * a task that ignored that could strand the deployer. `--min-native-left`
 * is checked before anything is sent.
 *
 *   yarn hh swap-via-lifi --network arc \
 *     --from 0x3600000000000000000000000000000000000000 \
 *     --to 0xeCe5cA8bf9220718E5727754026757512212cb3c \
 *     --amount 2000000 --dry-run true
 */

const LIFI_QUOTE_URL = 'https://li.quest/v1/quote'

const ERC20_ABI = [
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
  'function balanceOf(address) view returns (uint256)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function approve(address spender, uint256 amount) returns (bool)',
]

interface LifiQuote {
  tool?: string
  action?: { fromChainId?: number; toChainId?: number }
  estimate?: {
    fromAmount?: string
    toAmount?: string
    toAmountMin?: string
    approvalAddress?: string
    gasCosts?: Array<{ amount?: string; token?: { symbol?: string } }>
  }
  transactionRequest?: {
    to?: string
    data?: string
    value?: string
    chainId?: number
    gasLimit?: string
  }
  includedSteps?: Array<{ tool?: string }>
  message?: string
}

const units = (raw: bigint, decimals: number): string => {
  const d = BigInt(10) ** BigInt(decimals)
  const whole = raw / d
  const frac = (raw % d).toString().padStart(decimals, '0').replace(/0+$/, '')
  return frac ? `${whole}.${frac}` : `${whole}`
}

task('swap-via-lifi', 'Swaps one ERC-20 for another from the deployer, routed by LI.FI')
  .addParam('from', 'Address of the token to sell', undefined, types.string)
  .addParam('to', 'Address of the token to buy', undefined, types.string)
  .addParam('amount', 'Amount to sell, in the sold token\'s raw units', undefined, types.string)
  .addOptionalParam('slippage', 'Fractional slippage tolerance, e.g. 0.03 for 3%', 0.03, types.float)
  .addOptionalParam(
    'minNativeLeft',
    'Refuse to run if the wallet would be left with less than this much native gas, in whole units',
    5,
    types.float
  )
  .addOptionalParam('integrator', 'LI.FI integrator string', 'teller', types.string)
  .addOptionalParam('dryRun', 'Fetch and print the route without sending anything', false, types.boolean)
  .setAction(async (args, hre: HardhatRuntimeEnvironment): Promise<void> => {
    const { ethers, network } = hre
    const chainId = Number((await ethers.provider.getNetwork()).chainId)

    const [signer] = await ethers.getSigners()
    const sender = await signer.getAddress()

    const sell = new ethers.Contract(args.from as string, ERC20_ABI, signer)
    const buy = new ethers.Contract(args.to as string, ERC20_ABI, signer)

    const [sellSymbol, sellDecimals, buySymbol, buyDecimals] = await Promise.all([
      sell.symbol() as Promise<string>,
      sell.decimals() as Promise<bigint>,
      buy.symbol() as Promise<string>,
      buy.decimals() as Promise<bigint>,
    ])

    const amount = BigInt(args.amount as string)
    if (amount <= 0n) throw new Error('--amount must be positive')

    const sellBalance = (await sell.balanceOf(sender)) as bigint
    if (sellBalance < amount) {
      throw new Error(
        `deployer holds ${units(sellBalance, Number(sellDecimals))} ${sellSymbol}, ` +
          `which is less than the ${units(amount, Number(sellDecimals))} asked for`
      )
    }

    hre.log(`Swap on ${network.name} (chain ${chainId})`, { star: true })
    hre.log(`  wallet     ${sender}`)
    hre.log(
      `  selling    ${units(amount, Number(sellDecimals))} ${sellSymbol} ` +
        `(holds ${units(sellBalance, Number(sellDecimals))})`
    )
    hre.log(`  buying     ${buySymbol}`)

    const query = new URLSearchParams({
      fromChain: String(chainId),
      toChain: String(chainId),
      fromToken: args.from as string,
      toToken: args.to as string,
      fromAddress: sender,
      fromAmount: amount.toString(),
      slippage: String(args.slippage),
      integrator: args.integrator as string,
    })

    const response = await fetch(`${LIFI_QUOTE_URL}?${query.toString()}`)
    const quote = (await response.json()) as LifiQuote
    if (!response.ok || !quote.estimate || !quote.transactionRequest) {
      throw new Error(
        `LI.FI returned no route: ${quote.message ?? `HTTP ${response.status}`}`
      )
    }

    // Same chain in and out. The one failure mode that would look like success
    // is a bridge route: funds leave, the transaction confirms, and the pool is
    // still unfunded with the money on another chain.
    const from = quote.action?.fromChainId
    const to = quote.action?.toChainId
    if (from !== chainId || to !== chainId) {
      throw new Error(
        `refusing a route that is not a same-chain swap: fromChainId ${from}, toChainId ${to}, expected ${chainId} for both`
      )
    }
    if (quote.transactionRequest.chainId !== chainId) {
      throw new Error(
        `refusing a transaction for chain ${quote.transactionRequest.chainId}, expected ${chainId}`
      )
    }

    const toAmount = BigInt(quote.estimate.toAmount ?? '0')
    const toAmountMin = BigInt(quote.estimate.toAmountMin ?? '0')
    if (toAmountMin <= 0n) throw new Error('LI.FI returned a route with no minimum output')

    const spender = quote.estimate.approvalAddress
    if (!spender) throw new Error('LI.FI returned a route with no approval address')

    hre.log(`  route      ${quote.tool ?? 'unknown'} via ${(quote.includedSteps ?? []).map((s) => s.tool).join(' -> ')}`)
    hre.log(`  expecting  ${units(toAmount, Number(buyDecimals))} ${buySymbol}`)
    hre.log(`  minimum    ${units(toAmountMin, Number(buyDecimals))} ${buySymbol} at ${Number(args.slippage) * 100}% slippage`)
    hre.log(`  spender    ${spender}`)
    hre.log(`  target     ${quote.transactionRequest.to}`)

    // On a chain whose gas token is also the token being sold - Arc's USDC has
    // an 18-decimal native view and a 6-decimal ERC-20 view of one balance -
    // this is the check that stops a swap from stranding the deployer.
    //
    // Whether they are one balance is asked of the balances rather than kept in
    // a per-chain list, because the answer is observable: scale the native
    // balance down to the sold token's decimals and see whether it is the sold
    // balance. A 1-unit tolerance covers which way the ERC-20 view rounds.
    //
    // The scaling is the point. `amount` is in the sold token's units, and
    // subtracting it from a wei balance unscaled compares 6 decimals against
    // 18: on Arc that took 0.000000000006 off a 16.8 balance, so the floor this
    // guard exists to enforce passed every amount, including ones that would
    // have spent the gas.
    const nativeBefore = await ethers.provider.getBalance(sender)
    const minNativeLeft = ethers.parseEther(String(args.minNativeLeft))

    const scale = BigInt(10) ** BigInt(18 - Number(sellDecimals))
    const sellIsGasToken =
      Number(sellDecimals) <= 18 &&
      (nativeBefore / scale - sellBalance <= 1n) &&
      (sellBalance - nativeBefore / scale <= 1n)

    const spentFromNative = sellIsGasToken ? amount * scale : BigInt(0)
    const nativeAfterWorstCase =
      nativeBefore > spentFromNative ? nativeBefore - spentFromNative : BigInt(0)
    if (sellIsGasToken) {
      hre.log(`  gas token  ${sellSymbol} is this chain's gas; the swap spends it`)
    }
    if (nativeAfterWorstCase < minNativeLeft) {
      throw new Error(
        `refusing: wallet holds ${ethers.formatEther(nativeBefore)} native and the swap could leave ` +
          `${ethers.formatEther(nativeAfterWorstCase)}, below the ${args.minNativeLeft} floor. ` +
          `Lower --amount or --min-native-left deliberately.`
      )
    }

    if (args.dryRun === true) {
      hre.log('dry run — nothing sent', { star: true })
      return
    }

    const allowance = (await sell.allowance(sender, spender)) as bigint
    if (allowance < amount) {
      hre.log(`  approving  ${units(amount, Number(sellDecimals))} ${sellSymbol} to ${spender}`)
      // Some tokens refuse a non-zero-to-non-zero approval. Clearing first is
      // cheap and works on the ones that do not care.
      if (allowance > 0n) await (await sell.approve(spender, 0n)).wait()
      await (await sell.approve(spender, amount)).wait()
    }

    const buyBefore = (await buy.balanceOf(sender)) as bigint

    const sent = await signer.sendTransaction({
      to: quote.transactionRequest.to,
      data: quote.transactionRequest.data,
      value: quote.transactionRequest.value ?? '0x0',
      ...(quote.transactionRequest.gasLimit
        ? { gasLimit: (BigInt(quote.transactionRequest.gasLimit) * 12n) / 10n }
        : {}),
    })
    hre.log(`  sent       ${sent.hash}`)
    const receipt = await sent.wait()
    if (!receipt || receipt.status !== 1) {
      throw new Error(`swap transaction reverted: ${sent.hash}`)
    }

    // Asserted rather than assumed. A route can confirm and deliver nothing -
    // to a different recipient, or through a step that silently no-ops - and
    // the only honest check is the balance this wallet actually gained.
    const buyAfter = (await buy.balanceOf(sender)) as bigint
    const gained = buyAfter - buyBefore
    hre.log(`  received   ${units(gained, Number(buyDecimals))} ${buySymbol}`)
    if (gained < toAmountMin) {
      throw new Error(
        `swap confirmed but delivered ${units(gained, Number(buyDecimals))} ${buySymbol}, ` +
          `below the ${units(toAmountMin, Number(buyDecimals))} minimum the quote promised`
      )
    }

    const sellAfter = (await sell.balanceOf(sender)) as bigint
    hre.log(`  ${sellSymbol} left    ${units(sellAfter, Number(sellDecimals))}`)
    hre.log(`  ${buySymbol} held   ${units(buyAfter, Number(buyDecimals))}`)
    hre.log(`Done — swapped on ${network.name}`, { star: true })
  })
