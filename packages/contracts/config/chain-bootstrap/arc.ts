import { ChainBootstrapConfig } from './types'

/**
 * Arc (5042), Circle's L1.
 *
 * Two things about this chain are unlike every other one here, and both are
 * easy to get wrong.
 *
 * **USDC is the gas token, and it has two representations of one balance.**
 * The native asset is 18 decimals (msg.value, address.balance); the ERC-20
 * interface at 0x3600...0000 is 6 decimals. They are the same money. Circle's
 * own documentation says never to intermix them. Everything Teller touches -
 * principal, pool accounting, collateral maths - uses the 6-decimal ERC-20
 * address below. Only gas is 18.
 *
 * **There is no WETH and no wrapped native.** Uniswap's SDK aliases WETH[ARC]
 * to the same USDC interface, so anything that assumes WETH is a distinct
 * asset is wrong here rather than merely absent.
 *
 * ## Collateral
 *
 * The chain is two days old and its liquidity is memecoins. A sweep of every
 * pool DexScreener indexes found 47 pairs, all against USDC, and filtering to
 * the Uniswap V3 shape this protocol can price leaves:
 *
 *   ARGUS      $944k    v3    <- deepest V3 pool on the chain
 *   TOLLY      $628k    v3
 *   DUKE       $245k    v3
 *   LONG       $184k    v3
 *   COOL       $136k    v3
 *   ...nothing else above $101k
 *
 * The single largest pool on Arc is Arbit at $2.0M, and it is Uniswap **v4**,
 * which UniswapPricingLibraryV2 cannot read. Headline TVL for this chain
 * overstates what is lendable against by more than double.
 *
 * ARGUS is listed here at a deliberately punitive ratio. It does not clear the
 * bar the other chains' collateral does - it is a two-day-old memecoin, not an
 * asset whose price reconciles with anything off-chain - and it is listed
 * because launching Arc with one pool was chosen over launching it with none.
 * The 20% LTV is the whole of the risk control.
 */
const config: ChainBootstrapConfig = {
  network: 'arc',
  chainId: 5042,

  // The 6-decimal ERC-20 interface, never the 18-decimal native view.
  principal: {
    symbol: 'USDC',
    address: '0x3600000000000000000000000000000000000000',
    decimals: 6,
  },

  protocolFeeRecipient: '0x9ce73b7e864C60B9B1e2f32853264e1a5e5ecEe5',

  // 30 minutes, as elsewhere. The pool's observationCardinality is 4500 -
  // someone grew it deliberately - so a 1800s window is answerable with room
  // to spare. At 0.507s blocks that is ~3,550 blocks of history.
  twapInterval: 1800,

  // The chain's default band, which a pool may override on its own entry.
  // This one is priced for lending USDC against ordinary collateral; the ARGUS
  // pool below overrides it, because its collateral is not ordinary.
  interestRateLowerBound: 300, // 3% at zero utilization
  interestRateUpperBound: 1800, // 18% at the liquidity threshold

  liquidityThresholdPercent: 8000, // at most 80% of pool value lent out

  markets: [
    {
      key: 'short',
      label: '7 Day',
      durationSeconds: 7 * 24 * 60 * 60,
      // 5 minutes. Deliberately tight: the grace period is snapshotted into
      // each bid when it is submitted, so this governs new loans only, and a
      // short grace is what makes a delinquent loan actionable on a chain
      // whose collateral can gap while the underlying market is shut.
      paymentDefaultDuration: 5 * 60,
      bidExpirationTime: 24 * 60 * 60,
    },
    {
      key: 'long',
      label: '30 Day',
      durationSeconds: 30 * 24 * 60 * 60,
      // 5 minutes. Deliberately tight: the grace period is snapshotted into
      // each bid when it is submitted, so this governs new loans only, and a
      // short grace is what makes a delinquent loan actionable on a chain
      // whose collateral can gap while the underlying market is shut.
      paymentDefaultDuration: 5 * 60,
      bidExpirationTime: 24 * 60 * 60,
    },
  ],

  // ARGUS is only listed on the seven-day market, so that is the one whose
  // pool needs the owner's first deposit. The default here is `['long']`,
  // which on Arc would open nothing at all.
  activateMarkets: ['short'],

  collateral: [
    {
      symbol: 'ARGUS',
      token: '0xeCe5cA8bf9220718E5727754026757512212cb3c',
      pool: '0x6A3bAcAa6493734c1Ac221EBF42CF530A96C1e02',
      poolFee: 10000,
      // Read off the pool rather than assumed: token0 is USDC at 6 decimals,
      // token1 is ARGUS at 18.
      token0Decimals: 6,
      token1Decimals: 18,
      // The principal is token0 of this pool. `zeroForOne` is false in that
      // case and true when the principal is token1 - the opposite of what the
      // field's own docstring in types.ts says, and confirmed against two live
      // Robinhood routes plus `invert = !zeroForOne` in the pricing library.
      zeroForOne: false,
      // 500% collateralisation: a 20% LTV. Five times the cover the steadiest
      // collateral on any other chain is held to, because this is a memecoin
      // with $394k of USDC-side depth and nothing to reconcile its price
      // against.
      collateralRatio: 50000,
      // 30% at zero utilization, 60% at the liquidity threshold, against the
      // chain default of 3-18%.
      //
      // The chain default is a stablecoin rate: it is what a lender needs to
      // be paid for USDC that is idle most of the time and lent against
      // ordinary collateral. Nothing about it is priced for this. ARGUS is a
      // memecoin days old with $394k of USDC-side depth, and the 20% LTV
      // above is the *only* other risk control on the pool. A lender here is
      // underwriting a gap risk that a 3% floor does not pay for, and a
      // borrower paying 3% to short-finance a memecoin is being handed an
      // option cheaper than the risk they are passing on.
      //
      // 30-60% is the band the pool is actually worth to both sides. The floor
      // matters more than the ceiling: utilization on a pool this small sits
      // near zero most of the time, so the floor is the rate almost every loan
      // actually pays.
      //
      // This is a per-pool override rather than a change to the chain's
      // default because the default is right for the USDC the chain lends
      // generally, and wrong only where the collateral is this.
      interestRateLowerBound: 3000,
      interestRateUpperBound: 6000,
      // Seven days only. A thirty-day loan against an asset this young is a
      // bet on it still existing at maturity.
      markets: ['short'],
      note: 'Memecoin. Listed at a 20% LTV on the 7-day market only; the deepest Uniswap V3 pool on Arc at launch.',
    },
  ],

  // The long-tail side: lend ARGUS, take USDC as collateral.
  //
  // This was deliberately omitted at launch and is being added deliberately
  // now, so the reason it was left out is worth keeping rather than deleting.
  // Lending out a memecoin is not the same risk as lending against one. A loan
  // *against* ARGUS is exposed to ARGUS falling, which stops at zero. A loan
  // *of* ARGUS is exposed to ARGUS rising, which does not stop anywhere - and
  // this is a token days old with $394k of USDC-side depth, so the move that
  // would hurt is one a single buyer can cause.
  //
  // Two things bound it. The ratio is 600% - one tier tighter than the 500% on
  // the long side, following the same step every other chain's inverse pools
  // take (12500->16700, 16700->20000, 20000->25000, 25000->30000), and already
  // the most punitive number in the protocol. And the pool holds only what is
  // deposited into it: nothing here obliges anyone to fund it past activation.
  //
  // What it buys is the half of the marketplace that cannot exist without it.
  // Short is exactly the rows whose collateral is the chain's principal, and
  // ARGUS's Earn row has no supply side until a pool lends it - which is why
  // Arc shows a dash where a yield belongs.
  inverse: [
    {
      symbol: 'ARGUS',
      token: '0xeCe5cA8bf9220718E5727754026757512212cb3c',
      // Same Uniswap V3 pool as the long side, read in the other direction.
      pool: '0x6A3bAcAa6493734c1Ac221EBF42CF530A96C1e02',
      poolFee: 10000,
      // Unchanged: these describe the Uniswap pool, not the loan. token0 is
      // USDC at 6 decimals, token1 is ARGUS at 18.
      token0Decimals: 6,
      token1Decimals: 18,
      // Negated from the entry above. ARGUS is the principal here and it is
      // token1, and the route must still read principal per collateral.
      zeroForOne: true,
      // 600% collateralisation: a ~16.7% LTV. One tier tighter than the long
      // side, because the exposure is unbounded in the direction that hurts.
      collateralRatio: 60000,
      // Deliberately left on the chain's 3-18% rather than the 30-60% the long
      // side takes, and this pool is already live at those bounds.
      //
      // The two pools are not symmetric. On the long side the lender supplies
      // USDC and the rate is what pays them for memecoin gap risk. Here the
      // lender supplies ARGUS, and the return they care about is ARGUS itself
      // - a rate on top of that is the smaller term. The borrower, meanwhile,
      // is paying it in ARGUS, so a 30% floor on a token that can move 30% in
      // a day is not the control it looks like; the 600% collateralisation is.
      //
      // Stated rather than omitted, so the next reader does not take the
      // difference from the long side for an oversight.
      // Seven days only, matching the long side. There is no pool on the
      // thirty-day market in either direction.
      markets: ['short'],
      note: 'Long-tail lending pool: lends ARGUS against USDC. Deliberately tighter than the long side - a loan of a memecoin is exposed to it rising, which is unbounded.',
    },
  ],
}

export default config
