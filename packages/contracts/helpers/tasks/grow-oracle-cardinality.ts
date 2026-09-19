import { task, types } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

/**
 * Grow a Uniswap V3 pool's observation buffer so a TWAP can be read from it.
 *
 * WHY THIS EXISTS. A pool priced off a Uniswap TWAP needs the oracle pool to
 * hold observations spanning the window it asks for. A freshly created pool
 * ships with `observationCardinality == 1`, and one observation is not a
 * history: `observe([n, 0])` succeeds only while that single observation
 * happens to be older than `n`, so any swap makes the oracle unreadable again
 * for the next `n` seconds. A pool whose oracle intermittently reverts is worse
 * than one with a short window, because every borrow against it reverts too.
 *
 * Growing the buffer is permissionless - `increaseObservationCardinalityNext`
 * is callable by anyone, and costs only the gas to initialise the slots. It is
 * not instant: the slots are allocated here, but they fill as swaps write into
 * them, so the window a pool can actually answer widens over time rather than
 * the moment this returns. Check with `--probe` rather than assuming.
 *
 * This is what stands between Teller and having to create its own oracle pool
 * for a token that already trades. hyperRAM has $586k across eight Ramses
 * pairs, including $65k against the same USDC this chain lends - far deeper
 * than anything we would seed ourselves, and priced by a market rather than by
 * us. All it lacked was the buffer.
 *
 *   yarn hh grow-oracle-cardinality --network hyperevm \
 *     --pool 0x8aF68655C82175e5e4D46c76bD673F09b65De086 --target 300
 */

const UNIV3_POOL_ABI = [
  'function slot0() view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked)',
  'function increaseObservationCardinalityNext(uint16 observationCardinalityNext)',
  'function observe(uint32[] secondsAgos) view returns (int56[] tickCumulatives, uint160[] secondsPerLiquidityCumulativeX128s)',
  'function token0() view returns (address)',
  'function token1() view returns (address)',
  'function liquidity() view returns (uint128)',
]

/** The windows worth knowing about, shortest first. */
const PROBE_INTERVALS = [5, 30, 60, 300, 600, 1800, 3600]

task(
  'grow-oracle-cardinality',
  "Grow a Uniswap V3 pool's observation buffer so a TWAP can be read from it"
)
  .addParam('pool', 'The Uniswap V3 pool address', undefined, types.string)
  .addOptionalParam(
    'target',
    'Observation slots to allocate. Only ever grows - a value at or below the ' +
      'current next is a no-op on chain.',
    300,
    types.int
  )
  .addOptionalParam(
    'probe',
    'Report which TWAP windows the pool can answer today and send nothing',
    false,
    types.boolean
  )
  .setAction(async (args, hre: HardhatRuntimeEnvironment): Promise<void> => {
    const { ethers } = hre
    const deployer = await hre.getNamedSigner('deployer')
    const pool = await ethers.getContractAt(
      UNIV3_POOL_ABI,
      args.pool as string,
      deployer
    )

    const slot0 = await pool.slot0()
    const cardinality = Number(slot0[3])
    const next = Number(slot0[4])

    hre.log(`Oracle buffer on ${args.pool}`, { star: true })
    hre.log(`  network            ${hre.network.name}`)
    try {
      hre.log(
        `  token0/token1      ${await pool.token0()} / ${await pool.token1()}`
      )
      hre.log(`  liquidity          ${await pool.liquidity()}`)
    } catch {
      // A pool that cannot answer these is not a Uniswap V3 pool, and the
      // cardinality call below will say so far more clearly than a guess here.
    }
    hre.log(`  cardinality        ${cardinality}`)
    hre.log(`  cardinalityNext    ${next}`)

    // Which windows answer right now. This is the number that decides what
    // twapInterval a pool config may honestly ask for: a window the oracle
    // cannot answer is a pool that cannot lend.
    const answers: number[] = []
    for (const seconds of PROBE_INTERVALS) {
      try {
        await pool.observe([seconds, 0])
        answers.push(seconds)
      } catch {
        // OLD() - the buffer does not reach back that far yet.
      }
    }
    hre.log(
      `  answers today      ${
        answers.length
          ? answers.map((s) => `${s}s`).join(', ')
          : 'none beyond spot'
      }`
    )

    if (args.probe === true) {
      hre.log('probe only — nothing sent', { star: true })
      return
    }

    const target = args.target as number
    if (target <= next) {
      hre.log(
        `  already allocating ${next} slots, which is at or above the ${target} asked for — nothing to do`,
        { star: true }
      )
      return
    }

    hre.log(`  growing            ${next} -> ${target}`)
    const tx = await (pool as any).increaseObservationCardinalityNext(target)
    hre.log(`  sent               ${tx.hash}`)
    const receipt = await tx.wait()
    if (!receipt || receipt.status !== 1) {
      throw new Error(`increaseObservationCardinalityNext reverted: ${tx.hash}`)
    }

    const after = await pool.slot0()
    hre.log(`  cardinalityNext    ${Number(after[4])}`)
    if (Number(after[4]) < target) {
      throw new Error(
        `asked for ${target} slots, pool reports ${Number(after[4])} - the write did not take`
      )
    }

    // Said plainly because it is the part that surprises people: the slots are
    // allocated now, but `observationCardinality` only rises as swaps write
    // into them, so the window this pool can answer widens with trading rather
    // than on this transaction.
    hre.log('')
    hre.log(
      `Allocated. ${Number(after[3])} slots are live so far; the rest fill as swaps write`
    )
    hre.log(
      'into them, so re-probe before pointing a pool config at a longer window.'
    )
  })
