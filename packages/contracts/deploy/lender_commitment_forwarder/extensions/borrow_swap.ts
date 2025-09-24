import { DeployFunction } from 'hardhat-deploy/dist/types'

import { get_ecosystem_contract_address } from "../../../helpers/ecosystem-contracts-lookup" 

/*
// this is the swapRouter02 
const uniswapV3SwapRouter: { [networkName: string]: string } = {
  mainnet: '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45',
  polygon: '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45',
  arbitrum: '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45',
  base: '0x2626664c2603336E57B271c5C0b26F421741e481',
}

// this is the quoter view-only  https://github.com/Uniswap/view-quoter-v3
const uniswapV3Quoter: { [networkName: string]: string } = {
  mainnet: '0x5e55c9e631fae526cd4b0526c4818d6e0a9ef0e3',
  polygon: '0x5e55c9e631fae526cd4b0526c4818d6e0a9ef0e3',
  arbitrum: '0x5e55c9e631fae526cd4b0526c4818d6e0a9ef0e3',
  base: '0x222ca98f00ed15b1fae10b61c277703a194cf5d2',
}
*/

  let uniswapV3SwapRouter =  get_ecosystem_contract_address( hre.network.name, "uniswapV3SwapRouter" ) ;
  let uniswapV3Quoter =  get_ecosystem_contract_address( hre.network.name, "uniswapV3Quoter" ) ;
  
 
//const networksWithUniswapRouter: string[] = Object.keys(uniswapV3SwapRouter)

//const networksWithUniswapQuoter: string[] = Object.keys(uniswapV3Quoter)

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')
  

  const networkName = hre.network.name

  const flashSwapRolloverLoan = await hre.deployProxy('BorrowSwap', {
    unsafeAllow: ['constructor', 'state-variable-immutable'],
    constructorArgs: [
      await tellerV2.getAddress(),      
      uniswapV3SwapRouter ,
      uniswapV3Quoter 
      
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
  return !hre.network.live || !uniswapV3SwapRouter || !uniswapV3Quoter
}
export default deployFn
