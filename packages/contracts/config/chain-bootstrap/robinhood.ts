import { ChainBootstrapConfig } from './types'

/**
 * Robinhood Chain (4663).
 *
 * The chain's liquidity is overwhelmingly USDG paired against tokenized
 * equities and ETFs. A full sweep of the Uniswap V3 factory's PoolCreated
 * events found 5,590 USDG pools across 5,359 distinct counterparties, the vast
 * majority of which hold no meaningful liquidity. The eight collateral assets
 * below were the ones that cleared every check:
 *
 *   - at least ~$1.1M of two-sided liquidity in their deepest USDG pool
 *   - an observation cardinality that supports a 30 minute TWAP with room to
 *     spare (every pool here answers observe() out to 2 hours)
 *   - a TWAP price that reconciles with the real-world asset
 *
 * Collateral ratios are tiered by how far the asset can gap while the
 * underlying market is closed. Tokenized equities do not trade continuously,
 * so single names are held to a 40% LTV even though their pools are deep.
 */
const config: ChainBootstrapConfig = {
  network: 'robinhood',
  chainId: 4663,

  principal: {
    symbol: 'USDG',
    address: '0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168',
    decimals: 6,
  },

  protocolFeeRecipient: '0x9ce73b7e864C60B9B1e2f32853264e1a5e5ecEe5',

  // 30 minutes. Long enough that moving the oracle costs real capital, short
  // enough to track a gap when the underlying market reopens.
  twapInterval: 1800,

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

  collateral: [
    {
      symbol: 'SGOV',
      token: '0x92FD66527192E3e61d4DDd13322Aa222DE86F9B5',
      pool: '0xfAb520051f96F4D2a32c22B6a3dD7fFfdf231bFe',
      poolFee: 3000,
      token0Decimals: 6,
      token1Decimals: 18,
      // USDG is token0 of this pool, so the route is read
      // token0-per-token1 to yield principal per collateral.
      zeroForOne: false,
      collateralRatio: 12500,
      note: 'Cash equivalent: 0-3 month T-bill ETF. Lowest volatility collateral on the chain.',
    },
    {
      symbol: 'GLD',
      token: '0xC9a981FEE1F9DEc688bb123ccDeCc63D0deBFC4e',
      pool: '0x7A6A053eCCf1446A2633E05aA6D40D09381997ec',
      poolFee: 3000,
      token0Decimals: 6,
      token1Decimals: 18,
      // USDG is token0 of this pool, so the route is read
      // token0-per-token1 to yield principal per collateral.
      zeroForOne: false,
      collateralRatio: 16700,
      note: 'Commodity: gold trust. Low volatility, uncorrelated with equities.',
    },
    {
      symbol: 'QQQ',
      token: '0xD5f3879160bc7c32ebb4dC785F8a4F505888de68',
      pool: '0xD60A5d14dB690B7Afad71F76B108071D7175597d',
      poolFee: 500,
      token0Decimals: 6,
      token1Decimals: 18,
      // USDG is token0 of this pool, so the route is read
      // token0-per-token1 to yield principal per collateral.
      zeroForOne: false,
      collateralRatio: 16700,
      note: 'Broad index ETF: diversified across the Nasdaq 100, so no single-name risk.',
    },
    {
      symbol: 'WETH',
      token: '0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73',
      pool: '0x52e65B17fB6E5BA00Ed806f37Afcd2DaA50271Ca',
      poolFee: 100,
      token0Decimals: 18,
      token1Decimals: 6,
      // USDG is token1 of this pool, so the route is read
      // token1-per-token0 to yield principal per collateral.
      zeroForOne: true,
      collateralRatio: 20000,
      note: 'Crypto: deepest pool on the chain and the only 24/7 priced collateral here.',
    },
    {
      symbol: 'NVDA',
      token: '0xd0601CE157Db5bdC3162BbaC2a2C8aF5320D9EEC',
      pool: '0xd4EB21209C4D6093f80B5b84f5C45cc093EA14a3',
      poolFee: 500,
      token0Decimals: 6,
      token1Decimals: 18,
      // USDG is token0 of this pool, so the route is read
      // token0-per-token1 to yield principal per collateral.
      zeroForOne: false,
      collateralRatio: 25000,
      note: 'Single-name equity: gaps across market closures, so held to a 40% LTV.',
    },
    {
      symbol: 'GOOGL',
      token: '0x2e0847E8910a9732eB3fb1bb4b70a580ADAD4FE3',
      pool: '0x34D0dC122CF9A8Eb296fC5e0D3A233625D7d19b7',
      poolFee: 500,
      token0Decimals: 18,
      token1Decimals: 6,
      // USDG is token1 of this pool, so the route is read
      // token1-per-token0 to yield principal per collateral.
      zeroForOne: true,
      collateralRatio: 25000,
      note: 'Single-name equity: gaps across market closures, so held to a 40% LTV.',
    },
    {
      symbol: 'AMZN',
      token: '0x12f190a9F9d7D37a250758b26824B97CE941bF54',
      pool: '0x8AC92DA74AB5F3b1d024Dc1943Ad7e15Dc4179Ef',
      poolFee: 3000,
      token0Decimals: 18,
      token1Decimals: 6,
      // USDG is token1 of this pool, so the route is read
      // token1-per-token0 to yield principal per collateral.
      zeroForOne: true,
      collateralRatio: 25000,
      note: 'Single-name equity: gaps across market closures, so held to a 40% LTV.',
    },
    {
      symbol: 'TSLA',
      token: '0x322F0929c4625eD5bAd873c95208D54E1c003b2d',
      pool: '0xf4ACdAEEB7022862A763C9B1B885e11191c889E3',
      poolFee: 3000,
      token0Decimals: 18,
      token1Decimals: 6,
      // USDG is token1 of this pool, so the route is read
      // token1-per-token0 to yield principal per collateral.
      zeroForOne: true,
      collateralRatio: 25000,
      note: 'Single-name equity: gaps across market closures, so held to a 40% LTV.',
    },
    {
      symbol: 'MSTR',
      token: '0xec262a75e413fAfD0dF80480274532C79D42da09',
      pool: '0x17578C0e0D15da44f31677263114F71aE76653EA',
      poolFee: 10000,
      token0Decimals: 6,
      token1Decimals: 18,
      // USDG is token0 of this pool, so the route is read
      // token0-per-token1 to yield principal per collateral.
      zeroForOne: false,
      collateralRatio: 40000,
      // Short market only. MSTR is a leveraged bitcoin proxy wrapped in a
      // tokenized equity, so it carries crypto volatility *and* a closed
      // market to gap across, and its USDG pool holds ~$440k against the
      // ~$1.1M the rest of this list clears. Lending against it for a month
      // is a materially worse risk than lending for a week, so it is offered
      // for a week. 25% LTV rather than the 40% the other single names get,
      // for the same reasons.
      markets: ['short'],
      note: 'Single-name equity, leveraged bitcoin proxy. Thinnest pool here and short-market only.',
    },
    {
      symbol: 'STRATEGY',
      token: '0x168661C52E5922288dFb2b3f323b6Cf90eb21e18',
      // NOT THE DEEPEST MARKET. THE ONLY LEGIBLE ONE.
      //
      // Every other entry in this list names the pool where its collateral
      // actually trades. This one cannot: STRATEGY's real markets are all
      // Uniswap V4, which UniswapPricingLibraryV2 does not read -
      //
      //   STRATEGY / MSTR   $666,312   bankr (V4)
      //   STRATEGY / USDG   $50,067    uniswap-v4, 0.9%
      //   STRATEGY / USDG   $16,487    uniswap-v4, 3.69%
      //   STRATEGY / USDG   ~$2        uniswap-v3, 0.3%  <- this one
      //
      // The V3 pool named below is the last line: it exists because someone
      // created it, and it holds what they left in it. A price read from it
      // is not the market's price - it was 7.3% above the V4 market when this
      // entry was written, and nothing had arbitraged it back, because
      // arbitraging two dollars is not worth anyone's time.
      //
      // So this entry is deliberately inert until that pool is seeded. A
      // lending pool built on an oracle this thin does not merely invite
      // manipulation; it fails to *track*, which is the worse failure - the
      // cap below clips a price pushed up, and nothing clips a price that
      // simply stopped following the asset down.
      pool: '0x565c8e3a69b5aB39e2C15A1De90164123702a89f',
      poolFee: 3000,
      // Read off the pool: token0 is STRATEGY at 18 decimals, token1 is USDG
      // at 6.
      token0Decimals: 18,
      token1Decimals: 6,
      // USDG is token1 of this pool, so the route is read token1-per-token0
      // to yield principal per collateral.
      zeroForOne: true,
      // 500% collateralisation: a 20% LTV. The tightest ratio on this chain,
      // and the reason is the oracle rather than the asset - see above.
      collateralRatio: 50000,
      // 30% at zero utilization to 60% at the liquidity threshold, against
      // the chain's 3-18%.
      //
      // The chain default is priced for lending USDG against tokenized
      // equities with million-dollar pools behind them. This is a memecoin-
      // shaped token whose price Teller reads from a pool it had to be told
      // about. The floor is what matters: utilization on a new pool sits near
      // zero, so 30% is close to what every loan here actually pays.
      interestRateLowerBound: 3000,
      interestRateUpperBound: 6000,
      // Seven days only, like MSTR and for a stronger version of the same
      // reason: a thirty-day loan priced off an oracle this young is a bet
      // that the oracle is still honest at maturity.
      markets: ['short'],
      note: 'Requested listing. 20% LTV, 7-day only, 30-60%. Priced off the only V3 pool STRATEGY has, which must be seeded before this is deployed - its real markets are all V4.',
    },
  ],

  // Inverse pools: USDG is posted, the asset is drawn. See InversePoolConfig.
  //
  // Same Uniswap pools as above, read in the opposite direction, so the
  // liquidity and cardinality checks that qualified them still hold. Every
  // ratio is one tier tighter than the same asset on the long side, because a
  // loan of an asset is exposed to that asset rising and nothing bounds that.
  //
  // MSTR is absent: its long-side pool does not exist on chain yet, and a
  // leveraged bitcoin proxy is the last thing to lend out before the ordinary
  // direction has been proven.
  inverse: [
    {
      symbol: 'SGOV',
      token: '0x92FD66527192E3e61d4DDd13322Aa222DE86F9B5',
      pool: '0xfAb520051f96F4D2a32c22B6a3dD7fFfdf231bFe',
      poolFee: 3000,
      token0Decimals: 6,
      token1Decimals: 18,
      // Negated from this asset's entry above: SGOV is the principal here,
      // and the route must still read principal per collateral.
      zeroForOne: true,
      collateralRatio: 16700, // 59.9% LTV, vs 80.0% on the long side
      note: 'Shorting a T-bill ETF has almost no thesis, but it is the steadiest asset here, so it is the cheapest one to lend.',
    },
    {
      symbol: 'GLD',
      token: '0xC9a981FEE1F9DEc688bb123ccDeCc63D0deBFC4e',
      pool: '0x7A6A053eCCf1446A2633E05aA6D40D09381997ec',
      poolFee: 3000,
      token0Decimals: 6,
      token1Decimals: 18,
      // Negated from this asset's entry above: GLD is the principal here,
      // and the route must still read principal per collateral.
      zeroForOne: true,
      collateralRatio: 20000, // 50.0% LTV, vs 59.9% on the long side
      note: 'Gold. Uncorrelated with the equities here, so a short on it is not a duplicate of the others.',
    },
    {
      symbol: 'QQQ',
      token: '0xD5f3879160bc7c32ebb4dC785F8a4F505888de68',
      pool: '0xD60A5d14dB690B7Afad71F76B108071D7175597d',
      poolFee: 500,
      token0Decimals: 6,
      token1Decimals: 18,
      // Negated from this asset's entry above: QQQ is the principal here,
      // and the route must still read principal per collateral.
      zeroForOne: true,
      collateralRatio: 20000, // 50.0% LTV, vs 59.9% on the long side
      note: 'Index short. Diversified, so it gaps less than any single name in it.',
    },
    {
      symbol: 'WETH',
      token: '0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73',
      pool: '0x52e65B17fB6E5BA00Ed806f37Afcd2DaA50271Ca',
      poolFee: 100,
      token0Decimals: 18,
      token1Decimals: 6,
      // Negated from this asset's entry above: WETH is the principal here,
      // and the route must still read principal per collateral.
      zeroForOne: false,
      collateralRatio: 25000, // 40.0% LTV, vs 50.0% on the long side
      note: 'The one asset here that trades continuously, so it cannot gap across a closed market - but it is crypto-volatile.',
    },
    {
      symbol: 'NVDA',
      token: '0xd0601CE157Db5bdC3162BbaC2a2C8aF5320D9EEC',
      pool: '0xd4EB21209C4D6093f80B5b84f5C45cc093EA14a3',
      poolFee: 500,
      token0Decimals: 6,
      token1Decimals: 18,
      // Negated from this asset's entry above: NVDA is the principal here,
      // and the route must still read principal per collateral.
      zeroForOne: true,
      collateralRatio: 30000, // 33.3% LTV, vs 40.0% on the long side
      note: 'Single name. Can gap hard on earnings, and on the short side that gap is the direction that hurts.',
    },
    {
      symbol: 'GOOGL',
      token: '0x2e0847E8910a9732eB3fb1bb4b70a580ADAD4FE3',
      pool: '0x34D0dC122CF9A8Eb296fC5e0D3A233625D7d19b7',
      poolFee: 500,
      token0Decimals: 18,
      token1Decimals: 6,
      // Negated from this asset's entry above: GOOGL is the principal here,
      // and the route must still read principal per collateral.
      zeroForOne: false,
      collateralRatio: 30000, // 33.3% LTV, vs 40.0% on the long side
      note: 'Single name. Same earnings-gap exposure as the rest.',
    },
    {
      symbol: 'AMZN',
      token: '0x12f190a9F9d7D37a250758b26824B97CE941bF54',
      pool: '0x8AC92DA74AB5F3b1d024Dc1943Ad7e15Dc4179Ef',
      poolFee: 3000,
      token0Decimals: 18,
      token1Decimals: 6,
      // Negated from this asset's entry above: AMZN is the principal here,
      // and the route must still read principal per collateral.
      zeroForOne: false,
      collateralRatio: 30000, // 33.3% LTV, vs 40.0% on the long side
      note: 'Single name. Same earnings-gap exposure as the rest.',
    },
    {
      symbol: 'TSLA',
      token: '0x322F0929c4625eD5bAd873c95208D54E1c003b2d',
      pool: '0xf4ACdAEEB7022862A763C9B1B885e11191c889E3',
      poolFee: 3000,
      token0Decimals: 18,
      token1Decimals: 6,
      // Negated from this asset's entry above: TSLA is the principal here,
      // and the route must still read principal per collateral.
      zeroForOne: false,
      collateralRatio: 30000, // 33.3% LTV, vs 40.0% on the long side
      note: 'Single name, and the most volatile of them. Tightest ratio in this list alongside the other single names.',
    },
    {
      symbol: 'STRATEGY',
      token: '0x168661C52E5922288dFb2b3f323b6Cf90eb21e18',
      // Same pool as the long side, read the other way, and now seeded: it
      // holds ~1,706 STRATEGY / 8.84 USDG rather than the $1.62 it held when
      // the long entry above was written, and its observation buffer opened
      // from 1 to 300 when that liquidity was minted. Still a $16 pool. The
      // depth caveat on the long entry applies here word for word.
      pool: '0x565c8e3a69b5aB39e2C15A1De90164123702a89f',
      poolFee: 3000,
      token0Decimals: 18,
      token1Decimals: 6,
      // Negated from this asset's entry above: STRATEGY is the principal here,
      // and the route must still read principal per collateral, so it is read
      // token0-per-token1 - STRATEGY per USDG.
      zeroForOne: false,
      // 600% collateralisation: a 16.7% LTV, one tier tighter than the 20% on
      // the long side. Standard for this list, and worth more than usual here:
      // a loan *of* STRATEGY is exposed to STRATEGY rising, and nothing bounds
      // that the way the collateral's own floor bounds the other direction.
      collateralRatio: 60000,
      // Matched to the long side rather than to the chain, for the same reason
      // it was set there: the chain's 3-18% is priced for lending against
      // million-dollar equity pools, and this is neither.
      interestRateLowerBound: 3000,
      interestRateUpperBound: 6000,
      // Seven days only, like the long side.
      markets: ['short'],
      note: 'Requested reverse pool: lend STRATEGY, post USDG. 16.7% LTV, 7-day only, 30-60%.',
    },
  ],
}

export default config
