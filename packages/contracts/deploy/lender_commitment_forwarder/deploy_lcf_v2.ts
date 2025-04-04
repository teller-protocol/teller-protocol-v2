import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')
  const marketRegistry = await hre.contracts.get('MarketRegistry')

  let uniswapFactoryAddress: string
  switch (hre.network.name) {
    case 'mainnet':
    case 'goerli':
    case 'arbitrum':
    case 'optimism':
    case 'polygon':
    case 'localhost':
      uniswapFactoryAddress = '0x1F98431c8aD98523631AE4a59f267346ea31F984'
      break
    case 'base':
      uniswapFactoryAddress = '0x33128a8fC17869897dcE68Ed026d694621f6FDfD'
      break
    case 'sepolia':
      uniswapFactoryAddress = '0x0227628f3F023bb0B980b67D528571c95c6DaC1c'
      break
    default:
      throw new Error('No swap factory address found for this network')
  }


    const uniswapPricingLibraryV2 = await hre.contracts.get('UniswapPricingLibraryV2')

 


  const lenderCommitmentForwarderAlpha = await hre.deployProxy(
    'LenderCommitmentForwarderV2',
    {
      unsafeAllow: ['constructor', 'state-variable-immutable','external-library-linking'],
      constructorArgs: [
        await tellerV2.getAddress(),
        await marketRegistry.getAddress(),
        uniswapFactoryAddress,
      ],
      libraries: {

        UniswapPricingLibraryV2: await uniswapPricingLibraryV2.getAddress(),
      }
    }
  )

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-forwarder:v2:deploy'
deployFn.tags = [
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:v2',
  'lender-commitment-forwarder:v2:deploy',
]
deployFn.dependencies = ['teller-v2:deploy', 'market-registry:deploy','teller-v2:uniswap-pricing-library-v2']
export default deployFn
