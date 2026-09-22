import { ChainBootstrapConfig } from './types'

/**
 * HyperEVM (999) - not a launch, one asset added to a chain already running.
 *
 * Everything else in this directory brings a chain online: it creates the
 * markets, then a pool per collateral. HyperEVM has been live for months with
 * fourteen pools on market 2, none of them created from this repo. So this
 * config started out adding hyperRAM to that market and nothing else, and the
 * receipt at deployments/hyperevm/market-bootstrap.json is pre-seeded with the
 * market that already exists so no duplicate of it is created.
 *
 * It now also creates one market: a seven-day offers market, because the
 * chain has none and the thirty-day one it does have cannot carry a
 * seven-day loan. See the `shortOffers` entry for why.
 *
 * The consequence worth stating: the numbers under `markets` below for `long`
 * describe market 2 as it already is, read off chain. They are not applied - a
 * market already in the receipt is skipped - so if they are ever edited, the
 * edit changes nothing on chain and makes this file wrong. `shortOffers` is
 * the exception: it does not exist yet, so its numbers are real.
 *
 * ## hyperRAM
 *
 * 0x5555c2542836e7a6c8D3E133D5AA9773b65D5555, 18 decimals, ~$0.069.
 *
 * Eight Ramses pairs, ~$586k in total, and only one of them quotes it against
 * a stablecoin: 0x8aF68655... , hyperRAM/USDC, $65k. The deepest pair by far
 * is hyperRAM/fBOMB at $362k, which prices a memecoin in another memecoin and
 * is no use as an oracle.
 *
 * We were asked to seed a Project X pool and price against that instead.
 * Deliberately not done. A pool we seed ourselves would be thinner than $65k
 * and priced by us, which is a worse oracle wearing the clothes of a better
 * one: the manipulation it invites is our own liquidity moving. What the
 * Ramses pool lacked was not depth but history - `observationCardinality` was
 * 1, so `observe()` reverted OLD() for any window in the seconds after a swap.
 * That is fixable by anyone with gas (see helpers/tasks/grow-oracle-cardinality.ts),
 * and was.
 *
 * ## What actually bounds the risk here
 *
 * Not the TWAP. A 300s window on a $65k pool is cheap to push for a block, and
 * the direction that hurts is up - collateral quoted too high borrows more
 * than it is worth. The control is `maxPrincipalPerCollateralAmount`, set after
 * these pools are created from the price their own oracle quotes:
 *
 *   principalPerCollateral = cap == 0 ? oracle : min(oracle, cap)
 *
 * A capped pool cannot be made to over-lend by a price it is told, only by one
 * it is told is lower. Both pools below are capped on creation, and
 * `audit-pool-caps` exists so an uncapped one is noticed rather than
 * discovered.
 */
const config: ChainBootstrapConfig = {
  network: 'hyperevm',
  chainId: 999,

  // USDC, not USD₮0. The chain's existing pools lend USD₮0
  // (0xB8CE59FC...), and this one deliberately does not, because the oracle
  // decides: hyperRAM has one stablecoin pair on the chain and it is against
  // USDC. A pool lending USD₮0 against hyperRAM would have to price itself
  // through two hops, which a PoolRouteConfig cannot express in one route.
  principal: {
    symbol: 'USDC',
    address: '0xb88339CB7199b77E23DB6E890353E22632Ba630f',
    decimals: 6,
  },

  // The recipient this chain already has, not one we would prefer. Every other
  // file here names a recipient for a protocol being deployed; naming a
  // different one on a chain that has been live for months makes the bootstrap
  // write an owner-gated Safe call proposing to move an existing chain's fees,
  // which nobody asked for and which reads as a decision rather than as the
  // artefact of a default. It is the protocol owner's own address.
  protocolFeeRecipient: '0x004573E17574634A48CA808CF1df75f01e906E43',

  // 300s, against the 5s every existing pool on this chain uses.
  //
  // 5s is spot with extra steps: one block of a pushed price is most of the
  // window. 300s dilutes a single-block push about sixty-fold, and the buffer
  // now reaches back far enough to answer it - measured, not assumed, which is
  // what `grow-oracle-cardinality --probe` is for.
  //
  // It is not longer than that on purpose. The slots were allocated recently
  // and fill as swaps write into them, so a very long window is still anchored
  // to one old observation and reads stale rather than smooth - and stale can
  // read high, which is the same direction manipulation pushes. The cap covers
  // both; the window is chosen to keep the gap small in the meantime.
  twapInterval: 300,

  // The chain's own band, read off its live pools (WHYPE, PURR, APE all
  // 1500/7750). Unlike Arc's memecoin, this needs no per-pool override: 15% at
  // zero utilization to 77.5% at the threshold is already priced for assets of
  // exactly this kind, which is why the chain settled there.
  interestRateLowerBound: 1500,
  interestRateUpperBound: 7750,

  liquidityThresholdPercent: 8000,

  // Two entries, and they are not the same kind of thing. `long` is market 2,
  // which exists: every field on it is a description read on chain and none of
  // them are applied - see the note at the top of the file. Its marketplace fee
  // is 200 (2%), not the MARKET_FEE_PERCENT this directory uses. `shortOffers`
  // does not exist and will be created, at that MARKET_FEE_PERCENT.
  markets: [
    {
      key: 'long',
      label: '30 Day',
      durationSeconds: 30 * 24 * 60 * 60,
      paymentDefaultDuration: 5 * 60,
      bidExpirationTime: 7 * 24 * 60 * 60,
    },
    {
      // The one market in this file that does not already exist, and the
      // only entry here whose numbers are applied rather than describing
      // something read off chain.
      //
      // HyperEVM has exactly one market that trusts
      // LenderCommitmentForwarderAlpha - market 3, created outside this
      // repo - and its payment cycle is thirty days. That is a problem
      // specific to EMI markets: TellerV2 sizes payments through
      // V2Calculations, which for EMI lands in NumbersLib.pmt, and pmt
      // opens with
      //
      //     require(loanDuration >= cycleDuration)
      //
      // So a seven-day lending offer published into market 3 cannot be
      // drawn at all. It publishes, sits in the book looking entirely
      // normal, and reverts for every borrower who tries. Teller Pro's
      // on-demand lending wants a seven-day term everywhere, and on this
      // chain it has been forced back to thirty for exactly this reason.
      //
      // A market of its own is the only way to fix it. The forwarder slot
      // holds one address, so granting Alpha on market 1 (the seven-day
      // pools market) would not add offers, it would take that market's
      // pools off line - the same trap Arc hit, and why Base runs offers
      // on 22 and pools on 18.
      //
      // Worth noting that this task creates Bullet markets, so the pmt
      // floor above does not apply to what it makes: a Bullet loan is one
      // payment at the end, priced off the cycle rather than divided by
      // it, and never reaches pmt. The seven-day cycle here is what the
      // term should be, not a constraint being worked around.
      key: 'shortOffers',
      label: '7 Day Offers',
      purpose: 'offers',
      durationSeconds: 7 * 24 * 60 * 60,
      // Matching market 2's grace period, which is this chain's own.
      paymentDefaultDuration: 5 * 60,
      // A day, as on Arc's offers market. An offer carries its own expiry;
      // this governs unaccepted bids, and a short one keeps the book from
      // filling with stale ones.
      bidExpirationTime: 24 * 60 * 60,
    },
  ],

  activateMarkets: ['long'],

  collateral: [
    {
      symbol: 'hyperRAM',
      token: '0x5555c2542836e7a6c8D3E133D5AA9773b65D5555',
      // Ramses hyperRAM/USDC. The only pool on this chain that quotes
      // hyperRAM against a stablecoin.
      pool: '0x8aF68655C82175e5e4D46c76bD673F09b65De086',
      // 22222, read off `fee()`. Ramses is a Uniswap V3 fork with fee tiers of
      // its own rather than the 500/3000/10000 set, so this is not one of the
      // familiar numbers. It is recorded for auditability only - a
      // PoolRouteConfig carries the pool's address, not its fee, so nothing on
      // chain reads it.
      poolFee: 22222,
      // Read off the pool: token0 is hyperRAM at 18 decimals, token1 is USDC
      // at 6.
      token0Decimals: 18,
      token1Decimals: 6,
      // The principal (USDC) is token1 of this pool, so this is true - the
      // opposite of what the field's docstring in types.ts says, and confirmed
      // against the live WHYPE route on this same chain, which reads
      // `zeroForOne: true` for a USD₮0 principal that is also token1.
      zeroForOne: true,
      // 500% collateralisation: a 20% LTV, against the 40000 (25% LTV) the
      // chain's existing pools use. One tier tighter because hyperRAM's
      // stablecoin depth is $65k, where WHYPE's and PURR's run to millions -
      // the ratio is what covers the gap between the price the oracle reports
      // and the price a liquidation can actually get.
      collateralRatio: 50000,
      markets: ['long'],
      note: 'Requested by the token team. 20% LTV; priced off the single $65k Ramses hyperRAM/USDC pool, capped at creation.',
    },
  ],

  // The long-tail side: lend hyperRAM, take USDC as collateral. Asked for
  // alongside the pool above, and it is the half that makes an Earn row for
  // hyperRAM possible at all - without a pool lending it, there is no supply
  // side and the front end shows a dash where a yield belongs.
  inverse: [
    {
      symbol: 'hyperRAM',
      token: '0x5555c2542836e7a6c8D3E133D5AA9773b65D5555',
      // Same Ramses pool, read in the other direction.
      pool: '0x8aF68655C82175e5e4D46c76bD673F09b65De086',
      poolFee: 22222,
      // Unchanged: these describe the Uniswap pool, not the loan.
      token0Decimals: 18,
      token1Decimals: 6,
      // Negated from the entry above. hyperRAM is the principal here and it is
      // token0, and the route must still read principal per collateral.
      zeroForOne: false,
      // 600% collateralisation: a ~16.7% LTV, one tier tighter than the long
      // side. A loan against hyperRAM is exposed to hyperRAM falling, which
      // stops at zero; a loan of it is exposed to hyperRAM rising, which stops
      // nowhere - and on $65k of stablecoin depth the move that would hurt is
      // one buyer.
      collateralRatio: 60000,
      markets: ['long'],
      note: 'Lends hyperRAM against USDC. Tighter than the long side: a loan of an asset is exposed to it rising, which is unbounded.',
    },
  ],
}

export default config
