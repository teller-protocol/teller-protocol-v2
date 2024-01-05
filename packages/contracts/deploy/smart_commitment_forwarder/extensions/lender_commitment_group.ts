import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')
  const SmartCommitmentForwarder = await hre.contracts.get(
    'SmartCommitmentForwarder'
  )

  const tellerV2Address = await tellerV2.getAddress()

  const smartCommitmentForwarderAddress =
    await SmartCommitmentForwarder.getAddress()

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

  const lenderCommitmentGroupSmart = await hre.deployProxy(
    'LenderCommitmentGroup_Smart',
    {
      unsafeAllow: ['constructor', 'state-variable-immutable'],
      constructorArgs: [
        tellerV2Address,
        smartCommitmentForwarderAddress,
        uniswapV3FactoryAddress
      ],
      initArgs: [
        principalTokenAddress,
        collateralTokenAddress,
        marketId,
        maxLoanDuration,
        minInterestRate,
        liquidityThresholdPercent,
        loanToValuePercent,
        uniswapPoolFee
      ]
    }
  )

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-group-smart:deploy'
deployFn.tags = ['lender-commitment-group-smart']
deployFn.dependencies = [
  'teller-v2:deploy',
  'smart-commitment-forwarder:deploy'
]

deployFn.skip = async (hre) => {
  return true
  return !hre.network.live
}
export default deployFn