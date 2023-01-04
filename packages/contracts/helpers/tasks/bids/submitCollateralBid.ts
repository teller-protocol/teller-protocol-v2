import { task } from 'hardhat/config'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { CollateralManager, TellerV2 } from 'types/typechain'

export const submitCollateralBid = async (
  _args: any,
  hre: HardhatRuntimeEnvironment
): Promise<void> => {
  const { contracts, toBN, log, tokens } = hre

  const borrowerAddress = '0x5295b246F00F077c35735ACf9bBA35A6A6C13c62'

  // Load contracts
  const weth = await tokens.get('WETH')
  const usdc = await tokens.get('USDC')
  const tellerV2 = await contracts.get<TellerV2>('TellerV2')
  const collateralManager = await contracts.get<CollateralManager>(
    'CollateralManager'
  )

  // Submit bid
  const bidId = await tellerV2[
    'submitBid(address,uint256,uint256,uint32,uint16,string,address,(uint8,uint256,uint256,address)[])'
  ](
    usdc.address, // USDC
    1,
    '100000000',
    '31557600',
    '5000',
    '',
    borrowerAddress, // Receiver
    [
      {
        _collateralType: 0, // ERC20
        _amount: toBN(1, 16), // 0.01
        _tokenId: 0,
        _collateralAddress: weth.address, // WETH
      },
    ]
  )

  await weth.approve(collateralManager.address, toBN(1, 16))

  log(`Submitted collateral bid for ${borrowerAddress}`, { indent: 4 })
}

task('submit-collateral-bid', 'submits a collateral backed bid')
    .setAction(submitCollateralBid)
