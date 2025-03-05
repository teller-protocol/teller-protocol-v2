import { DeployFunction } from 'hardhat-deploy/dist/types'

const uniswapV3Factory: { [networkName: string]: string } = {
  mainnet: '0x1F98431c8aD98523631AE4a59f267346ea31F984',
  polygon: '0x1F98431c8aD98523631AE4a59f267346ea31F984',
  arbitrum: '0x1F98431c8aD98523631AE4a59f267346ea31F984',
  base: '0x33128a8fC17869897dcE68Ed026d694621f6FDfD',
}

const weth9: { [networkName: string]: string } = {
  mainnet: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
  polygon: '0x7ceb23fd6bc0add59e62ac25578270cff1b9f619',
  arbitrum: '0x82af49447d8a07e3bd95bd0d56f35241523fbab1',
  base: '0x4200000000000000000000000000000000000006',
}

const networksWithUniswap: string[] = Object.keys(uniswapV3Factory)

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')
  

  const networkName = hre.network.name

  const flashSwapRolloverLoan = await hre.deployProxy('BorrowSwap', {
    unsafeAllow: ['constructor', 'state-variable-immutable'],
    constructorArgs: [
      await tellerV2.getAddress(),      
      uniswapV3Factory[networkName],
      weth9[networkName],
    ],
  })

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-forwarder:extensions:borrow-swap:deploy'
deployFn.tags = [
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:extensions',
  'lender-commitment-forwarder:extensions:deploy',
  'lender-commitment-forwarder:extensions:borrow-swap',
  'lender-commitment-forwarder:extensions:borrow-swap:deploy',
]
deployFn.dependencies = [
  'teller-v2:deploy',
   
]

deployFn.skip = async (hre) => {
  return !hre.network.live || !networksWithUniswap.includes(hre.network.name)
}
export default deployFn
