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
  ],
}

export default config
