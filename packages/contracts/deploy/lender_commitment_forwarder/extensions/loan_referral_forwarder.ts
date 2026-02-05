import { DeployFunction } from 'hardhat-deploy/dist/types'


import { get_ecosystem_contract_address } from "../../../helpers/ecosystem-contracts-lookup" 



const deployFn: DeployFunction = async (hre) => {
  hre.log('Getting TellerV2 contract...')
  const tellerV2 = await hre.contracts.get('TellerV2')
  hre.log('TellerV2 contract retrieved:', !!tellerV2)
   



  const networkName = hre.network.name




/*
const uniswapV3Factory: { [networkName: string]: string } = {
  mainnet: '0x1F98431c8aD98523631AE4a59f267346ea31F984',
  polygon: '0x1F98431c8aD98523631AE4a59f267346ea31F984',
  arbitrum: '0x1F98431c8aD98523631AE4a59f267346ea31F984',
  base: '0x33128a8fC17869897dcE68Ed026d694621f6FDfD',
}

*/



  let uniswapV3FactoryAddress =  get_ecosystem_contract_address( hre.network.name, "uniswapV3Factory" ) ;
   
      const deployer = await hre.getNamedSigner('deployer')


  hre.log('Deploying Loan Referral Forwarder V2...')
  hre.log('Network name:' )
    hre.log(  hre.network.name)

   hre.log('Deployer:' )
          
      hre.log(  deployer.address  )

      hre.log('TellerV2 address:' )
          
        let tellerV2Address = await tellerV2.getAddress(); 
      
      hre.log( tellerV2Address  )

  const LoanReferralForwarder = await hre.deployProxy('LoanReferralForwarderV2', {
    unsafeAllow: ['constructor', 'state-variable-immutable'],
    constructorArgs: [
      tellerV2Address  
    ],
  })

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-forwarder:extensions:loan-referral-forwarder-v2:deploy'
deployFn.tags = [
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:extensions',
  'lender-commitment-forwarder:extensions:deploy',
  'lender-commitment-forwarder:extensions:loan-referral-forwarder',
  'lender-commitment-forwarder:extensions:loan-referral-forwarder-v2:deploy',
]
deployFn.dependencies = [
  'teller-v2:deploy',
  'lender-commitment-forwarder:deploy',
]
 
deployFn.skip = async (hre) => {
  
 
  return !hre.network.live || !['sepolia' ,   'mainnet', 'arbitrum', 'katana', 'hyperevm' ].includes(hre.network.name)
}

export default deployFn
