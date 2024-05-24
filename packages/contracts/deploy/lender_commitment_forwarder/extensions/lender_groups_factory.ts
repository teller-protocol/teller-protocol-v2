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

  const lenderGroupsFactory = await hre.deployProxy(
    'LenderCommitmentGroupFactory',
    {
      unsafeAllow: ['constructor', 'state-variable-immutable'],
      constructorArgs: [
        tellerV2Address,
        smartCommitmentForwarderAddress,
        uniswapV3FactoryAddress,
      ],
    }
  )

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-group-factory:deploy'
deployFn.tags = ['lender-commitment-group-factory']
deployFn.dependencies = [
  'teller-v2:deploy',
  'teller-v2:init',
  'smart-commitment-forwarder:deploy',
]

deployFn.skip = async (hre) => {
  return !hre.network.live || !['sepolia', 'polygon'].includes(hre.network.name)
}
export default deployFn
