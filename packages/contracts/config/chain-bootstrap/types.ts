/**
 * Launch configuration for bringing a brand new chain online.
 *
 * Every chain Teller launches on gets the same shape: a short-duration and a
 * long-duration market, both charging the standard marketplace fee, plus a set
 * of LenderCommitmentGroup V2 pools that lend the chain's main stablecoin
 * against its most liquid collateral.
 *
 * To onboard a chain, drop a `<network>.ts` in this directory exporting a
 * `ChainBootstrapConfig` and run:
 *
 *   yarn hh bootstrap-markets --network <network>
 */

/** Marketplace fee charged by each market. 10000 == 100%, so 100 == 1%. */
export const MARKET_FEE_PERCENT = 100

/** Protocol fee taken by TellerV2, in basis points. 10000 == 100%, so 5 == 5bps. */
export const PROTOCOL_FEE_BPS = 5

export interface MarketConfig {
  /** Stable key used to name the market in the bootstrap receipt. */
  key: string
  /** Human label, also used to build the market URI. */
  label: string
  /** Loan term in seconds. Doubles as the payment cycle for bullet loans. */
  durationSeconds: number
  /** How long a borrower may be delinquent before the loan can be defaulted. */
  paymentDefaultDuration: number
  /** How long an unaccepted bid stays live. */
  bidExpirationTime: number
}

export interface CollateralConfig {
  /** Token symbol, used for logging and the bootstrap receipt. */
  symbol: string
  /** Collateral token address. */
  token: string
  /** Uniswap V3 pool quoting this collateral against the principal token. */
  pool: string
  /** Pool fee tier, recorded for auditability. */
  poolFee: number
  /** Decimals of the pool's token0 and token1, in that order. */
  token0Decimals: number
  token1Decimals: number
  /**
   * True when the principal token is token0 of the pool. The pricing library
   * reads the route in the principal -> collateral direction.
   */
  zeroForOne: boolean
  /**
   * Over-collateralization ratio. 10000 == 100%, so 20000 means a borrower
   * must post twice the value they draw (a 50% LTV).
   */
  collateralRatio: number
  /**
   * Market keys this collateral gets a pool on. Omitted means every market,
   * which is the usual case. Naming a subset is for an asset thin or volatile
   * enough that a long loan against it is a worse risk than a short one.
   */
  markets?: string[]
  /** Free-text note on why this asset sits in the tier it does. */
  note?: string
}

export interface ChainBootstrapConfig {
  /** hardhat network name this config applies to. */
  network: string
  chainId: number
  /** The chain's main stablecoin. Every pool lends this. */
  principal: { symbol: string; address: string; decimals: number }
  /** Where protocol fees are swept. */
  protocolFeeRecipient: string
  /** TWAP window, in seconds, used for every pool oracle route. */
  twapInterval: number
  /** Interest rate floor and ceiling in bps, interpolated by utilization. */
  interestRateLowerBound: number
  interestRateUpperBound: number
  /** Max share of pool value that may be lent out at once. 10000 == 100%. */
  liquidityThresholdPercent: number
  markets: MarketConfig[]
  collateral: CollateralConfig[]
}
