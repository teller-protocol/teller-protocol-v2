import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')
  const SmartCommitmentForwarder = await hre.contracts.get(
    'SmartCommitmentForwarder'
  )

  const tellerV2Address = await tellerV2.getAddress()

  const smartCommitmentForwarderAddress =
    await SmartCommitmentForwarder.getAddress()

  let uniswapV3FactoryAddress: string
  switch (hre.network.name) {
    case 'mainnet':
    case 'goerli':
    case 'arbitrum':
    case 'optimism':
    case 'polygon':
    case 'localhost':
      uniswapV3FactoryAddress = '0x1F98431c8aD98523631AE4a59f267346ea31F984'
      break
    case 'base':
      uniswapV3FactoryAddress = '0x33128a8fC17869897dcE68Ed026d694621f6FDfD'
      break
    case 'sepolia':
      uniswapV3FactoryAddress = '0x0227628f3F023bb0B980b67D528571c95c6DaC1c'
      break
    default:
      throw new Error('No swap factory address found for this network')
  }

  const networkName = hre.network.name

  //created pool https://sepolia.etherscan.io/tx/0x8ea20095c821f6066252457d7f0438030bc65bb441e1bea56c6ae0efd63016f0

  //  for polygon ??
 // const principalTokenAddress = '0x72292c8464a33f6b5f6efcc0213a89a98c68668b' //0xbtc
  // const collateralTokenAddress = '0xfff9976782d46cc05630d1f6ebab18b2324d6b14' //weth
  
  //for sepolia 
  const collateralTokenAddress = '0x72292c8464a33f6b5f6efcc0213a89a98c68668b' //0xbtc
  const principalTokenAddress = '0xfff9976782d46cc05630d1f6ebab18b2324d6b14' //weth
  
  
  const uniswapPoolFee = 3000

  //use market id of 44 for polygon 
  const marketId = 4  //for sepolia
  const minInterestRate = 400
  const maxInterestRate = 800
  const maxLoanDuration = 10368000
  const liquidityThresholdPercent = 7500
  const loanToValuePercent = 12500 //make sure this functions as normal.  If under 100%, getting much better loan terms and i wont repay.  If it is over 100%, it will likely repay since overcollateralized.
  const twapInterval = 5

  const lenderCommitmentGroupSmart = await hre.deployProxy(
    'LenderCommitmentGroup_Smart',
    {
      unsafeAllow: ['constructor', 'state-variable-immutable'],
      constructorArgs: [
        tellerV2Address,
        smartCommitmentForwarderAddress,
        uniswapV3FactoryAddress,
      ],
      initArgs: [
        principalTokenAddress,
        collateralTokenAddress,
        marketId,
        maxLoanDuration,
        minInterestRate,
        maxInterestRate,
        liquidityThresholdPercent,
        loanToValuePercent,
        uniswapPoolFee,
        twapInterval,
      ],
    }
  )

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-group-smart:deploy'
deployFn.tags = ['lender-commitment-group-smart']
deployFn.dependencies = [
  'teller-v2:deploy',
  'smart-commitment-forwarder:deploy',
]

deployFn.skip = async (hre) => {
  return !hre.network.live || !['sepolia', 'polygon'].includes(hre.network.name)
}
export default deployFn
