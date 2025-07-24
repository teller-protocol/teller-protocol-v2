 


import { DeployFunction } from 'hardhat-deploy/dist/types'

import { UpgradeableBeacon } from 'types/typechain'


import { get_ecosystem_contract_address } from "../../../../helpers/ecosystem-contracts-lookup" 
/*

This deploys a one-off test contract of the lender commitment group contract !

This is not needed for production 

*/


const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')
  const SmartCommitmentForwarder = await hre.contracts.get(
    'SmartCommitmentForwarder'
  )


  const tellerV2Address = await tellerV2.getAddress()


  const uniswapPricingLibrary = await hre.contracts.get('UniswapPricingLibrary')

 

  const smartCommitmentForwarderAddress =
    await SmartCommitmentForwarder.getAddress()

  let uniswapV3FactoryAddress  =  get_ecosystem_contract_address( hre.network.name, "uniswapV3Factory" ) ;
 


  const commitmentGroupBeacon = await hre.deployBeacon<UpgradeableBeacon>(
    'LenderCommitmentGroup_Smart',
    {
      customName: 'LenderCommitmentGroupBeacon',
      unsafeAllow: ['constructor', 'state-variable-immutable','external-library-linking'],
      constructorArgs: [
        tellerV2Address,
        smartCommitmentForwarderAddress,
        uniswapV3FactoryAddress,
      ],
      libraries: {
        
        UniswapPricingLibrary: await uniswapPricingLibrary.getAddress(),
      },
      
    }
  )

 
  //is this necessary ? 
  //isnt this just an implementation?
  
  const { protocolTimelock , protocolOwnerSafe } = await hre.getNamedAccounts()
  hre.log('Transferring ownership of CommitmentGroupBeacon to Gnosis Safe...')
  await commitmentGroupBeacon.transferOwnership(protocolTimelock)
  hre.log('done.')

  return true
}

 

 

// tags and deployment
deployFn.id = 'lender-commitment-group-beacon:deploy'
deployFn.tags = ['lender-commitment-group-beacon']
deployFn.dependencies = [
  'teller-v2:deploy',
  'smart-commitment-forwarder:deploy',
  'teller-v2:uniswap-pricing-library', 
  'teller-v2:uniswap-pricing-library-v2'
]

deployFn.skip = async (hre) => {
   return !hre.network.live || !['sepolia'   ].includes(hre.network.name)
}
export default deployFn
