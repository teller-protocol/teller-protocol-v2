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
 
// Where the referral rail runs. Teller Pro pays referrals out of the referred
// borrower's principal on the loan's own transaction, so a lending chain
// missing from this list still borrows fine but pays the referrer nothing.
// Add a chain here when Teller starts lending on it, not when the forwarder
// happens to get deployed there.
//
// Not inverted to "any live network": this deployFn depends on teller-v2:deploy
// and lender-commitment-forwarder:deploy, so on a chain with no TellerV2 it
// would try to deploy a whole protocol -- the thing deploy-chain.sh's RUN_TAGS
// guard exists to prevent. Inverting it needs its own PR.
const REFERRAL_FORWARDER_NETWORKS = [
  'mainnet',
  'arbitrum',
  'base',
  'polygon',
  'optimism',
  'xdc',
  'bsc',
  'hyperevm',
  'robinhood',
  'arc',
  'apechain',
  'katana',
  'sepolia',
]

deployFn.skip = async (hre) => {
  return (
    !hre.network.live || !REFERRAL_FORWARDER_NETWORKS.includes(hre.network.name)
  )
}

export default deployFn
