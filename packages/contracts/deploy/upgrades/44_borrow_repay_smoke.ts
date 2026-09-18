import { DeployFunction } from 'hardhat-deploy/dist/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import fs from 'fs'
import path from 'path'

/**
 * Take a loan out of a live pool and pay it back, against the real chain.
 *
 * Everything else here checks a contract answers correctly. This checks the
 * thing a borrower actually does: post collateral, draw principal, owe
 * interest, repay, get the collateral back. It exercises the forwarder
 * approval, the collateral escrow, the pool's rate curve and TellerV2's
 * repayment accounting in one pass, on a chain where all of those are newly
 * deployed and none of them had ever carried a loan.
 *
 * It is a smoke test, not a fixture: it runs against whatever the pool holds,
 * borrows a deliberately small amount, and leaves no position behind. Opt in
 * with BORROW_REPAY_SMOKE=<receipt key>, e.g. `long:WETH`, because it moves
 * the deployer's own funds and should never be something a deploy does on its
 * way past.
 */

const SCF_ABI = [
  'function acceptSmartCommitmentWithRecipient(address _commitmentAddress, uint256 _principalAmount, uint256 _collateralAmount, uint256 _collateralTokenId, address _collateralTokenAddress, address _recipient, uint16 _interestRate, uint32 _loanDuration) returns (uint256 bidId)',
]
const TELLER_ABI = [
  'function approveMarketForwarder(uint256 _marketId, address _forwarder)',
  'function hasApprovedMarketForwarder(uint256 _marketId, address _forwarder, address _account) view returns (bool)',
  'function repayLoanFull(uint256 _bidId)',
  'function calculateAmountOwed(uint256 _bidId, uint256 _timestamp) view returns (tuple(uint256 principal, uint256 interest))',
  'function collateralManager() view returns (address)',
  'function bids(uint256) view returns (address borrower, address receiver, address lender, uint256 marketplaceId, bytes32 _metadataURI, tuple(address lendingToken, uint256 principal, uint32 timestamp, uint32 acceptedTimestamp, uint32 lastRepaidTimestamp, uint32 loanDuration) loanDetails, tuple(uint256 paymentCycleAmount, uint32 paymentCycle, uint16 APR) terms, uint8 state, uint8 paymentType)',
  'event SubmittedBid(uint256 indexed bidId, address indexed borrower, address receiver, bytes32 indexed metadataURI)',
]
const POOL_ABI = [
  'function principalToken() view returns (address)',
  'function collateralToken() view returns (address)',
  'function getMarketId() view returns (uint256)',
  'function getMinInterestRate(uint256) view returns (uint16)',
  'function getPrincipalAmountAvailableToBorrow() view returns (uint256)',
  'function collateralRatio() view returns (uint16)',
  'function getMaxLoanDuration() view returns (uint32)',
  'function calculateCollateralRequiredToBorrowPrincipal(uint256) view returns (uint256)',
]
const ERC20_ABI = [
  'function balanceOf(address) view returns (uint256)',
  'function allowance(address,address) view returns (uint256)',
  'function approve(address,uint256) returns (bool)',
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
]

const poolFromReceipt = (
  hre: HardhatRuntimeEnvironment,
  key: string
): string | undefined => {
  const receiptPath = path.join(
    (hre.config.paths as { deployments?: string }).deployments ??
      path.join(hre.config.paths.root, 'deployments'),
    hre.network.name,
    'market-bootstrap.json'
  )
  if (!fs.existsSync(receiptPath)) return undefined
  const receipt = JSON.parse(fs.readFileSync(receiptPath, 'utf8'))
  return receipt?.pools?.[key]?.address
}

const deployFn: DeployFunction = async (hre) => {
  const key = process.env.BORROW_REPAY_SMOKE as string
  const poolAddress = poolFromReceipt(hre, key)!
  const deployer = await hre.getNamedSigner('deployer')
  const me = await deployer.getAddress()

  const fmt = (v: bigint, d: bigint) => {
    const base = 10n ** d
    return `${v / base}.${(v % base).toString().padStart(Number(d), '0').slice(0, 6)}`
  }

  hre.log('----------')
  hre.log(`Borrow/repay smoke test on ${hre.network.name}: ${key} (${poolAddress})`)

  const pool = await hre.ethers.getContractAt(POOL_ABI, poolAddress, deployer)
  const tellerV2Address = await (await hre.contracts.get('TellerV2')).getAddress()
  const tellerV2 = await hre.ethers.getContractAt(
    TELLER_ABI,
    tellerV2Address,
    deployer
  )
  const forwarderAddress = await (
    await hre.contracts.get('SmartCommitmentForwarder')
  ).getAddress()
  const forwarder = await hre.ethers.getContractAt(
    SCF_ABI,
    forwarderAddress,
    deployer
  )

  const [principalAddress, collateralAddress, marketId, available, ratioBps, duration] =
    await Promise.all([
      pool.principalToken() as Promise<string>,
      pool.collateralToken() as Promise<string>,
      pool.getMarketId() as Promise<bigint>,
      pool.getPrincipalAmountAvailableToBorrow() as Promise<bigint>,
      pool.collateralRatio() as Promise<bigint>,
      pool.getMaxLoanDuration() as Promise<bigint>,
    ])

  const principal = await hre.ethers.getContractAt(ERC20_ABI, principalAddress, deployer)
  const collateral = await hre.ethers.getContractAt(ERC20_ABI, collateralAddress, deployer)
  const [pSym, pDec, cSym, cDec] = await Promise.all([
    principal.symbol() as Promise<string>,
    principal.decimals() as Promise<bigint>,
    collateral.symbol() as Promise<string>,
    collateral.decimals() as Promise<bigint>,
  ])

  // Borrow a tenth of what the pool holds, so the test never drains it and
  // never depends on being the only borrower.
  const borrowAmount = available / 10n
  if (borrowAmount === 0n) {
    throw new Error(`${key} has no principal available to borrow`)
  }

  // Collateral is priced by the pool itself, so ask it rather than guessing:
  // the ratio is what it will demand, plus a margin for the price moving
  // between this read and the transaction.
  const collateralRequired =
    (((await pool.calculateCollateralRequiredToBorrowPrincipal(
      borrowAmount
    )) as bigint) *
      102n) /
    100n

  const collateralHeld: bigint = await collateral.balanceOf(me)
  hre.log(`  pool has ${fmt(available, pDec)} ${pSym} available, ratio ${ratioBps} bps`)
  hre.log(`  borrowing ${fmt(borrowAmount, pDec)} ${pSym} against ${fmt(collateralRequired, cDec)} ${cSym}`)
  hre.log(`  deployer holds ${fmt(collateralHeld, cDec)} ${cSym}`)
  if (collateralHeld < collateralRequired) {
    throw new Error(
      `deployer holds ${collateralHeld} ${cSym}, needs ${collateralRequired}`
    )
  }

  const collateralManagerAddress: string = await tellerV2.collateralManager()
  if ((await collateral.allowance(me, collateralManagerAddress)) < collateralRequired) {
    await (await collateral.approve(collateralManagerAddress, collateralRequired)).wait()
  }
  if (!(await tellerV2.hasApprovedMarketForwarder(marketId, forwarderAddress, me))) {
    await (await tellerV2.approveMarketForwarder(marketId, forwarderAddress)).wait()
  }

  // The rate the pool quotes now, with the same headroom the front end uses -
  // the curve moves with utilisation, and this borrow moves it.
  const minRate: bigint = await pool.getMinInterestRate(borrowAmount)
  const rate = (minRate * 105n + 99n) / 100n

  const principalBefore: bigint = await principal.balanceOf(me)
  const collateralBefore: bigint = await collateral.balanceOf(me)

  const borrowTx = await forwarder.acceptSmartCommitmentWithRecipient(
    poolAddress,
    borrowAmount - 100n,
    collateralRequired,
    0,
    collateralAddress,
    me,
    rate,
    duration
  )
  const borrowReceipt = await borrowTx.wait()

  // The bid id comes off SubmittedBid rather than a return value, which a
  // transaction does not give back.
  const submitted = borrowReceipt!.logs
    .map((l: any) => {
      try {
        return tellerV2.interface.parseLog(l)
      } catch {
        return null
      }
    })
    .find((l: any) => l?.name === 'SubmittedBid')
  if (!submitted) throw new Error('no SubmittedBid event in the borrow receipt')
  const bidId: bigint = submitted.args[0]

  const principalAfterBorrow: bigint = await principal.balanceOf(me)
  const collateralAfterBorrow: bigint = await collateral.balanceOf(me)
  hre.log(`  borrowed  bid ${bidId}  tx ${borrowTx.hash}`)
  hre.log(`    ${pSym} ${fmt(principalBefore, pDec)} -> ${fmt(principalAfterBorrow, pDec)}`)
  hre.log(`    ${cSym} ${fmt(collateralBefore, cDec)} -> ${fmt(collateralAfterBorrow, cDec)}`)

  if (principalAfterBorrow <= principalBefore) {
    throw new Error(`borrow did not deliver ${pSym}`)
  }
  if (collateralAfterBorrow >= collateralBefore) {
    throw new Error(`borrow did not take ${cSym} as collateral`)
  }

  const owed = await tellerV2.calculateAmountOwed(bidId, Math.floor(Date.now() / 1000) + 60)
  const total = owed.principal + owed.interest
  hre.log(`    owed ${fmt(owed.principal, pDec)} principal + ${fmt(owed.interest, pDec)} interest`)

  // Repaying costs more than was drawn, by the interest. On a pool this small
  // the difference is dust, but the deployer still has to be holding it.
  if ((await principal.allowance(me, tellerV2Address)) < total * 2n) {
    await (await principal.approve(tellerV2Address, total * 2n)).wait()
  }
  const repayTx = await tellerV2.repayLoanFull(bidId)
  await repayTx.wait()

  const bid = await tellerV2.bids(bidId)
  const principalAfterRepay: bigint = await principal.balanceOf(me)
  const collateralAfterRepay: bigint = await collateral.balanceOf(me)
  hre.log(`  repaid    tx ${repayTx.hash}`)
  hre.log(`    ${pSym} ${fmt(principalAfterBorrow, pDec)} -> ${fmt(principalAfterRepay, pDec)}`)
  hre.log(`    ${cSym} ${fmt(collateralAfterBorrow, cDec)} -> ${fmt(collateralAfterRepay, cDec)}`)
  hre.log(`    bid state ${bid.state} (3 = PAID)`)

  // 3 is BidState.PAID. Anything else and the loan is still open, whatever
  // the balances happen to look like.
  if (Number(bid.state) !== 3) {
    throw new Error(`bid ${bidId} is in state ${bid.state}, expected 3 (PAID)`)
  }
  if (collateralAfterRepay < collateralBefore) {
    throw new Error(
      `collateral was not returned in full: ${collateralAfterRepay} < ${collateralBefore}`
    )
  }

  hre.log('')
  hre.log(`  PASS - borrowed and repaid ${fmt(borrowAmount, pDec)} ${pSym}, collateral returned`)
  hre.log('----------')

  return true
}

deployFn.id = 'borrow-repay-smoke'
deployFn.tags = ['borrow-repay-smoke']
deployFn.dependencies = []
deployFn.skip = async (hre) => {
  const key = process.env.BORROW_REPAY_SMOKE
  if (!hre.network.live || !key) return true
  if (!poolFromReceipt(hre, key)) {
    throw new Error(
      `BORROW_REPAY_SMOKE="${key}" is not a pool in ${hre.network.name}'s bootstrap receipt`
    )
  }
  return false
}

export default deployFn
