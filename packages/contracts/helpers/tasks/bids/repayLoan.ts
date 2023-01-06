import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { TellerV2 } from 'types/typechain'

interface RepayLoanArgs {
  bidId: number
}

export const repayLoan = async (
  args: RepayLoanArgs,
  hre: HardhatRuntimeEnvironment
): Promise<void> => {
  const { contracts, log, tokens, toBN } = hre
  const { bidId } = args

  // Load contracts
  const tellerV2 = await contracts.get<TellerV2>('TellerV2')
  const usdc = await tokens.get('USDC')

  // Get total amount due to repay
  const amountDue = await tellerV2['calculateAmountOwed(uint256)'](bidId)
  log(`${amountDue}`)
  // Approve funds to be repaid
  await usdc.approve(tellerV2.address, toBN(110, 6))

  // Repay loan
  await tellerV2.repayLoanFull(bidId)

  log(`Loan ${bidId} repaid`, { indent: 4 })
}

task('repay-loan', 'repays a loan in full')
  .addParam('bidId', 'The id of the bid to repay')
  .setAction(repayLoan)
