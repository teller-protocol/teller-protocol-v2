import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')

  const SmartCommitmentForwarder = await hre.contracts.get(
    'SmartCommitmentForwarder'
  )

  const smartCommitmentForwarderAddress =
    await SmartCommitmentForwarder.getAddress()

  //for sepolia
  const lenderCommitmentGroupProxyAddress =
    '0x62babfc668494145051a473112de8d3e93d3927e'

  const LenderCommitmentGroup = await hre.ethers.getContractFactory(
    'LenderCommitmentGroup_Smart'
  )

  //for sepolia
  const uniswapV3FactoryAddress = '0x0227628f3F023bb0B980b67D528571c95c6DaC1c'

  const networkName = hre.network.name

  //created pool https://sepolia.etherscan.io/tx/0x8ea20095c821f6066252457d7f0438030bc65bb441e1bea56c6ae0efd63016f0

  let principalTokenAddress = '0xfff9976782d46cc05630d1f6ebab18b2324d6b14' //weth
  let collateralTokenAddress = '0x72292c8464a33f6b5f6efcc0213a89a98c68668b' //0xbtc
  let uniswapPoolFee = 3000

  let marketId = 1
  let minInterestRate = 100
  let maxLoanDuration = 5000000
  let liquidityThresholdPercent = 10000
  let loanToValuePercent = 10000 //make sure this functions as normal.  If over 100%, getting much better loan terms and i wont repay.  If it is under 100%, it will likely repay.

  /*

  (
    apeSwapProxyAddress,
    ApeSwap,
    {
      unsafeAllow: ['state-variable-immutable', 'constructor'],
      constructorArgs: [
        swapFactoryAddress,
        contracts.TellerV2.address,
        contracts.LenderCommitmentForwarderStaging.address
      ]
    }
  )

  */
  const lenderCommitmentGroupSmart = await hre.upgrades.upgradeProxy(
    lenderCommitmentGroupProxyAddress,
    LenderCommitmentGroup,
    {
      unsafeAllow: ['constructor', 'state-variable-immutable'],
      constructorArgs: [
        smartCommitmentForwarderAddress,
        uniswapV3FactoryAddress
      ] /*,
      initArgs: [
        principalTokenAddress,
        collateralTokenAddress,
        marketId,
        maxLoanDuration,
        minInterestRate,
        liquidityThresholdPercent,
        loanToValuePercent,
        uniswapPoolFee
      ]*/
    }
  )

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-group-upgrade'
deployFn.tags = [
  'upgrade',
  'lender-commitment-group',
  'lender-commitment-group-upgrade'
]
deployFn.dependencies = ['teller-v2:deploy']
deployFn.skip = async (hre) => {
  return !hre.network.live || !['sepolia'].includes(hre.network.name)
}
export default deployFn
