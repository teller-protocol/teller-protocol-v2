import { DeployFunction } from 'hardhat-deploy/dist/types'

const uniswapV3SwapRouter: { [networkName: string]: string } = {
  mainnet: '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45',
  polygon: '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45',
  arbitrum: '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45',
  base: '0x2626664c2603336E57B271c5C0b26F421741e481',
}
 

const networksWithUniswap: string[] = Object.keys(uniswapV3Factory)

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')
  

  const networkName = hre.network.name

  const flashSwapRolloverLoan = await hre.deployProxy('BorrowSwap', {
    unsafeAllow: ['constructor', 'state-variable-immutable'],
    constructorArgs: [
      await tellerV2.getAddress(),      
      uniswapV3SwapRouter[networkName],
      
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
