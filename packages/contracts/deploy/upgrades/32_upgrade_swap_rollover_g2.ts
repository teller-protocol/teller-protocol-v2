import { DeployFunction } from 'hardhat-deploy/dist/types'

 import { get_ecosystem_contract_address } from "../../helpers/ecosystem-contracts-lookup" 


const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('SwapRolloverLoan G2: Proposing upgrade...')

  const networkName = hre.network.name

  const swapRolloverLoan = await hre.contracts.get('SwapRolloverLoan')
  const tellerV2 = await hre.contracts.get('TellerV2')
   

    let uniswapV3FactoryAddress =  get_ecosystem_contract_address( hre.network.name, "uniswapV3Factory" ) ;
   
   let weth9Address =  get_ecosystem_contract_address( hre.network.name, "weth9" ) ;
     


  await hre.upgrades.proposeBatchTimelock({
    title: 'Swap Rollover Loan Extension Upgrade',
    description: ` 
# SwapRolloverLoan G2 (Extensions Upgrade)

* Upgrades the swap rollover loan contract to work with sushi.
`,
    _steps: [
      {
        proxy: flashRolloverLoan,
        implFactory: await hre.ethers.getContractFactory('SwapRolloverLoan'),

        opts: {
          unsafeAllow: ['constructor', 'state-variable-immutable'],
          constructorArgs: [
            await tellerV2.getAddress(),
         
                    
              uniswapV3FactoryAddress,
              weth9Address,
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
deployFn.id = 'lender-commitment-forwarder:extensions:flash-swap-rollover:g2-upgrade'
deployFn.tags = [
  'proposal',
  'upgrade',
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:extensions',
  'lender-commitment-forwarder:extensions:flash-swap-rollover',
  'lender-commitment-forwarder:extensions:flash-swap-rollover:g2-upgrade',
]
deployFn.dependencies = [
  'teller-v2:deploy',
  'lender-commitment-forwarder:staging:deploy',
  'lender-commitment-forwarder:extensions:flash-swap-rollover:deploy',
]
deployFn.skip = async (hre) => {
  return !(
    hre.network.live &&
    [ 'goerli', 'sepolia', 'katana'].includes(
      hre.network.name
    )
  )
}
export default deployFn
