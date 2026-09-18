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

  interestRateLowerBound: 300, // 3% at zero utilization
  interestRateUpperBound: 1800, // 18% at the liquidity threshold

  liquidityThresholdPercent: 8000, // at most 80% of pool value lent out

  markets: [
    {
      key: 'short',
      label: '7 Day',
      durationSeconds: 7 * 24 * 60 * 60,
      paymentDefaultDuration: 3 * 24 * 60 * 60,
      bidExpirationTime: 24 * 60 * 60,
    },
    {
      key: 'long',
      label: '30 Day',
      durationSeconds: 30 * 24 * 60 * 60,
      paymentDefaultDuration: 7 * 24 * 60 * 60,
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
      // Seven days only. A thirty-day loan against an asset this young is a
      // bet on it still existing at maturity.
      markets: ['short'],
      note: 'Memecoin. Listed at a 20% LTV on the 7-day market only; the deepest Uniswap V3 pool on Arc at launch.',
    },
  ],

  // `inverse` is deliberately omitted. An inverse pool lends the collateral and
  // takes the principal - it is what makes an asset shortable - and lending out
  // a memecoin is a different risk from lending against one: the exposure is to
  // it rising, which does not stop anywhere. Short will be empty on Arc, which
  // is the correct thing for it to be.
}

export default config
