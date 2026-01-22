import { DeployFunction } from 'hardhat-deploy/dist/types'

import { get_ecosystem_contract_address } from "../../helpers/ecosystem-contracts-lookup" 


const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('UniswapPricingHelper: Proposing upgrade...')


 

  const tellerV2 = await hre.contracts.get('TellerV2')
 
  const tellerV2Address = await tellerV2.getAddress()
 
  

  const uniswapPricingHelper = await hre.contracts.get('UniswapPricingHelper')
    


   const UniswapPricingHelperImplementation =
    await hre.ethers.getContractFactory('UniswapPricingHelper')
 
    const proxyAddress = await uniswapPricingHelper.getAddress()
 

 
  await hre.upgrades.proposeBatchTimelock({
    title: 'UniswapPricingHelper: Add Collateral Compute Fn',
    description: ` 
# UniswapPricingHelper

* A patch to add collateral compute fn.
`,
    _steps: [
      {
        proxy: proxyAddress,
        implFactory: UniswapPricingHelperImplementation,

        opts: {
          unsafeAllow: ['constructor', 'state-variable-immutable'],
          //  kind: 'transparent', 

          constructorArgs: [
            tellerV2Address 
          ],
        },
      },
    ],
  })

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'uniswap-pricing-helper:add-compute-fn'
deployFn.tags = ['uniswap-pricing-helper']
deployFn.dependencies = [ 
  
  'uniswap-pricing-helper:deploy'
]

deployFn.skip = async (hre) => {
  return !hre.network.live || !['sepolia' ].includes(hre.network.name)
}
export default deployFn
