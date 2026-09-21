import { getAddress } from 'ethers'
import { task, types } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

/**
 * Put liquidity into a Uniswap V3 pool, so a price read from it means
 * something.
 *
 * WHY THIS EXISTS. `grow-oracle-cardinality` makes a pool's TWAP *readable*.
 * It cannot make it *honest*, and the two are different problems. A pool with
 * a full observation buffer and two dollars in it answers every window you ask
 * for and answers them wrong: STRATEGY's only Uniswap V3 pool on Robinhood
 * held $1.62 and sat 7.3% above the market its token actually trades in,
 * because arbitraging two dollars is not worth anyone's gas.
 *
 * Teller reads V3 and only V3. Where a token's real market is V4 - as
 * STRATEGY's is, $666k of it - there is no deep V3 pool to point at and the
 * choice is between seeding one and not lending against the token at all.
 * This is the seeding.
 *
 * WHAT DEPTH BUYS, AND WHAT IT DOES NOT. Moving a full-range V3 pool's price
 * by a factor k costs roughly `L · √P · (√k − 1)` of the quote token, which is
 * about 41% of the quote reserve to double it. So depth raises the cost of
 * pushing a price up - but `maxPrincipalPerCollateralAmount` already bounds
 * what that push can extract, so it is not the interesting half.
 *
 * The interesting half is that depth is what makes arbitrage worth doing, and
 * arbitrage is the only thing that makes a pool *track*. A price that quietly
 * stops following its asset downward is the failure no cap can catch: the cap
 * clips a number that is too high, and a stale number is too high exactly when
 * the collateral has fallen. That is why this task exists and why the amount
 * matters more than the fact of seeding.
 *
 * FULL RANGE, DELIBERATELY. A concentrated position earns more fees and stops
 * pricing the moment the market leaves its range - which for an oracle is the
 * whole job abandoned at the worst moment. This mints across the entire tick
 * range: worse as a trade, correct as a price source.
 *
 *   yarn hh seed-univ3-pool --network robinhood \
 *     --pool 0x565c8e3a69b5aB39e2C15A1De90164123702a89f \
 *     --amount0 1600 --amount1 7.8 --dry-run true
 */

const POOL_ABI = [
  'function token0() view returns (address)',
  'function token1() view returns (address)',
  'function fee() view returns (uint24)',
  'function tickSpacing() view returns (int24)',
  'function liquidity() view returns (uint128)',
  'function slot0() view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked)',
]

const ERC20_ABI = [
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
  'function balanceOf(address) view returns (uint256)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function approve(address spender, uint256 amount) returns (bool)',
]

const NPM_ABI = [
  'function factory() view returns (address)',
  'function mint((address token0,address token1,uint24 fee,int24 tickLower,int24 tickUpper,uint256 amount0Desired,uint256 amount1Desired,uint256 amount0Min,uint256 amount1Min,address recipient,uint256 deadline)) payable returns (uint256 tokenId,uint128 liquidity,uint256 amount0,uint256 amount1)',
]

/** Uniswap V3's absolute tick bounds. */
const MIN_TICK = -887272
const MAX_TICK = 887272

const units = (raw: bigint, decimals: number): string => {
  const d = BigInt(10) ** BigInt(decimals)
  const frac = (raw % d).toString().padStart(decimals, '0').replace(/0+$/, '')
  return frac ? `${raw / d}.${frac.slice(0, 8)}` : `${raw / d}`
}

/** Human amount -> raw, without going through float. */
const rawFrom = (amount: string, decimals: number): bigint => {
  const [whole, frac = ''] = amount.trim().split('.')
  const padded = (frac + '0'.repeat(decimals)).slice(0, decimals)
  return (
    BigInt(whole || '0') * BigInt(10) ** BigInt(decimals) +
    BigInt(padded || '0')
  )
}

task(
  'seed-univ3-pool',
  'Add full-range liquidity to a Uniswap V3 pool, so its TWAP is worth reading'
)
  .addParam('pool', 'The Uniswap V3 pool to seed', undefined, types.string)
  .addParam(
    'amount0',
    "Amount of the pool's token0 to add, in whole tokens",
    undefined,
    types.string
  )
  .addParam(
    'amount1',
    "Amount of the pool's token1 to add, in whole tokens",
    undefined,
    types.string
  )
  .addOptionalParam(
    'positionManager',
    'NonfungiblePositionManager. Defaults to the one this chain mints with.',
    '',
    types.string
  )
  .addOptionalParam(
    'slippageBps',
    'How far below the desired amounts the mint may settle before it reverts. ' +
      'A full-range mint at the current price consumes the two sides in the ' +
      "pool's own ratio, so the side that is proportionally larger is only " +
      'partly used - this bounds how much worse than asked for that may be.',
    500,
    types.int
  )
  .addOptionalParam(
    'dryRun',
    'Print what would be minted and send nothing',
    false,
    types.boolean
  )
  .setAction(async (args, hre: HardhatRuntimeEnvironment): Promise<void> => {
    const { ethers } = hre
    const deployer = await hre.getNamedSigner('deployer')
    const sender = await deployer.getAddress()

    // Every address this task touches goes through getAddress first. Not
    // politeness: ethers rejects a mixed-case address whose EIP-55 checksum
    // does not match, and it rejects it at call time, three minutes into a
    // deploy, with a message about an argument rather than about the constant
    // somebody typed by hand. Normalising at the edge means a lowercase or
    // miscapitalised address is corrected here or rejected here.
    const poolAddress = getAddress(args.pool as string)
    const pool = await ethers.getContractAt(POOL_ABI, poolAddress, deployer)
    const [
      token0Address,
      token1Address,
      fee,
      tickSpacing,
      slot0,
      liquidityBefore,
    ] = await Promise.all([
      pool.token0() as Promise<string>,
      pool.token1() as Promise<string>,
      pool.fee() as Promise<bigint>,
      pool.tickSpacing() as Promise<bigint>,
      pool.slot0(),
      pool.liquidity() as Promise<bigint>,
    ])

    if ((slot0[0] as bigint) === BigInt(0)) {
      throw new Error(
        `${poolAddress} has no price: it was created but never initialised, so there is nothing to add liquidity around.`
      )
    }

    const token0 = await ethers.getContractAt(
      ERC20_ABI,
      token0Address,
      deployer
    )
    const token1 = await ethers.getContractAt(
      ERC20_ABI,
      token1Address,
      deployer
    )
    const [sym0, dec0, sym1, dec1] = await Promise.all([
      token0.symbol() as Promise<string>,
      token0.decimals() as Promise<bigint>,
      token1.symbol() as Promise<string>,
      token1.decimals() as Promise<bigint>,
    ])

    const desired0 = rawFrom(args.amount0 as string, Number(dec0))
    const desired1 = rawFrom(args.amount1 as string, Number(dec1))
    if (desired0 <= BigInt(0) && desired1 <= BigInt(0)) {
      throw new Error('both amounts are zero; nothing to add')
    }

    const [balance0, balance1] = await Promise.all([
      token0.balanceOf(sender) as Promise<bigint>,
      token1.balanceOf(sender) as Promise<bigint>,
    ])
    if (balance0 < desired0 || balance1 < desired1) {
      throw new Error(
        `wallet holds ${units(balance0, Number(dec0))} ${sym0} and ${units(balance1, Number(dec1))} ${sym1}, ` +
          `short of the ${units(desired0, Number(dec0))} / ${units(desired1, Number(dec1))} asked for`
      )
    }

    // The widest range the tick spacing allows. See the note at the top: a
    // narrower one prices better until the market leaves it, and then does not
    // price at all.
    const spacing = Number(tickSpacing)
    const tickLower = Math.ceil(MIN_TICK / spacing) * spacing
    const tickUpper = Math.floor(MAX_TICK / spacing) * spacing

    const npmAddress = args.positionManager
      ? getAddress(args.positionManager as string)
      : positionManagerFor(hre.network.name)
    const npm = await ethers.getContractAt(NPM_ABI, npmAddress, deployer)

    // Checked rather than trusted: minting through something that is not this
    // chain's position manager would approve two tokens to an arbitrary
    // address and call a function that may mean anything.
    const npmFactory = (await npm.factory()) as string
    hre.log(`Seeding ${poolAddress}`, { star: true })
    hre.log(`  network          ${hre.network.name}`)
    hre.log(`  pair             ${sym0} / ${sym1} at ${Number(fee) / 10_000}%`)
    hre.log(`  pool liquidity   ${liquidityBefore}`)
    hre.log(`  position manager ${npmAddress}`)
    hre.log(`  its factory      ${npmFactory}`)
    hre.log(
      `  range            ${tickLower} .. ${tickUpper} (full, spacing ${spacing})`
    )
    hre.log(`  adding           ${units(desired0, Number(dec0))} ${sym0}`)
    hre.log(`                   ${units(desired1, Number(dec1))} ${sym1}`)

    const bps = BigInt(
      Math.max(0, Math.min(10_000, args.slippageBps as number))
    )
    const min0 = (desired0 * (BigInt(10_000) - bps)) / BigInt(10_000)
    const min1 = (desired1 * (BigInt(10_000) - bps)) / BigInt(10_000)

    if (args.dryRun === true) {
      hre.log('dry run — nothing sent', { star: true })
      return
    }

    for (const [token, sym, desired, decimals] of [
      [token0, sym0, desired0, Number(dec0)],
      [token1, sym1, desired1, Number(dec1)],
    ] as const) {
      if (desired === BigInt(0)) continue
      const allowance = (await token.allowance(sender, npmAddress)) as bigint
      if (allowance < desired) {
        hre.log(`  approving        ${units(desired, decimals)} ${sym}`)
        // Some tokens refuse a non-zero-to-non-zero approval.
        if (allowance > BigInt(0))
          await (await token.approve(npmAddress, 0)).wait()
        await (await token.approve(npmAddress, desired)).wait()
      }
    }

    const deadline = Math.floor(Date.now() / 1000) + 20 * 60
    const tx = await npm.mint({
      token0: token0Address,
      token1: token1Address,
      fee,
      tickLower,
      tickUpper,
      amount0Desired: desired0,
      amount1Desired: desired1,
      amount0Min: min0,
      amount1Min: min1,
      recipient: sender,
      deadline,
    })
    hre.log(`  sent             ${tx.hash}`)
    const receipt = await tx.wait()
    if (!receipt || receipt.status !== 1) {
      throw new Error(`mint reverted: ${tx.hash}`)
    }

    // Asserted from the pool rather than read off the return value: the mint
    // can succeed against a position that is not in range, and what this task
    // is for is the pool's own depth.
    const liquidityAfter = (await pool.liquidity()) as bigint
    hre.log('')
    hre.log(`  pool liquidity   ${liquidityBefore} -> ${liquidityAfter}`)
    if (liquidityAfter <= liquidityBefore) {
      throw new Error(
        `mint confirmed but the pool's active liquidity did not rise (${liquidityBefore} -> ${liquidityAfter})`
      )
    }

    const [after0, after1] = await Promise.all([
      token0.balanceOf(sender) as Promise<bigint>,
      token1.balanceOf(sender) as Promise<bigint>,
    ])
    hre.log(
      `  spent            ${units(balance0 - after0, Number(dec0))} ${sym0}`
    )
    hre.log(
      `                   ${units(balance1 - after1, Number(dec1))} ${sym1}`
    )
    hre.log('')
    hre.log(
      'Seeded. The pool prices against this depth now; re-read its TWAP before',
      { star: true }
    )
    hre.log(
      'setting any cap from it, because the price it quotes has just moved.'
    )
  })

/**
 * The position manager this chain actually mints with.
 *
 * Not one constant, because the canonical address is not universal: on
 * Robinhood the V3 periphery sits at an address of its own, and 0xC36442b4...
 * over there is an unrelated 2kb contract that would have taken two approvals
 * and then reverted. Found the way it had to be found - the sender of a Mint
 * on a live pool of this chain's factory is the periphery that minted it, and
 * that address answers as "Uniswap V3 Positions NFT-V1".
 */
function positionManagerFor(network: string): string {
  const known = knownPositionManager(network)
  // getAddress, not the literal: the table below is written in lowercase on
  // purpose, so that the only capitalisation this task ever uses is the one
  // keccak produces. A hand-checksummed constant is a constant that can be
  // wrong, and it fails at the first call rather than at load.
  if (known) return getAddress(known)
  throw new Error(
    `No NonfungiblePositionManager known for ${network}. Find it (the sender of a Mint ` +
      `on one of this chain's V3 pools), check it reports this chain's factory, then pass ` +
      `--position-manager or add it here.`
  )
}

function knownPositionManager(network: string): string | undefined {
  switch (network) {
    case 'mainnet':
    case 'mainnet_live_fork':
    case 'goerli':
    case 'arbitrum':
    case 'optimism':
    case 'polygon':
    case 'base':
      return '0xc36442b4a4522e871399cd717abdd847ab11fe88'
    // Read off chain 4663: the sender of every Mint on its live V3 pools, and
    // it answers as "Uniswap V3 Positions NFT-V1" with this chain's factory.
    case 'robinhood':
      return '0x73991a25c818bf1f1128deaab1492d45638de0d3'
    default:
      return undefined
  }
}
