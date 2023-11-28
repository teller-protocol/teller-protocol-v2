import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')
  const SmartCommitmentForwarder = await hre.contracts.get(
    'SmartCommitmentForwarder'
  )

  const smartCommitmentForwarderAddress =
    await SmartCommitmentForwarder.getAddress()

  //for sepolia
  const uniswapV3FactoryAddress = '0x0227628f3F023bb0B980b67D528571c95c6DaC1c'

  const networkName = hre.network.name

  let principalTokenAddress = '0x7b79995e5f793a07bc00c21412e50ecae098e7f9'
  let collateralTokenAddress = '0x932b4ecd408db358a2ac12289c889701418167ed'
  let uniswapPoolFee = 300
  let marketId = 1
  let minInterestRate = 100
  let maxLoanDuration = 5000000
  let liquidityThresholdPercent = 10000
  let loanToValuePercent = 10000 //make sure this functions as expected

  const lenderCommitmentGroupSmart = await hre.deployProxy(
    'LenderCommitmentGroup_Smart',
    {
      unsafeAllow: ['constructor', 'state-variable-immutable'],
      constructorArgs: [
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
  return !hre.network.live
}
export default deployFn
