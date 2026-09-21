import { skipUnlessChainSupports } from '../../../../config/chains/features'
 


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


 // const uniswapPricingLibraryV2 = await hre.contracts.get('UniswapPricingLibraryV2')

   const uniswapPricingHelper = await hre.contracts.get('UniswapPricingHelper')
    const uniswapPricingHelperAddress = await uniswapPricingHelper.getAddress()


  const smartCommitmentForwarderAddress =
    await SmartCommitmentForwarder.getAddress()

  let uniswapV3FactoryAddress  =  get_ecosystem_contract_address( hre.network.name, "uniswapV3Factory" ) ;
   

  const commitmentGroupBeacon = await hre.deployBeacon<UpgradeableBeacon>(
    'LenderCommitmentGroup_Pool_V2',
    {
      customName: 'LenderCommitmentGroupBeaconV2',
      unsafeAllow: ['constructor', 'state-variable-immutable','external-library-linking'],
      constructorArgs: [
        tellerV2Address,
        smartCommitmentForwarderAddress,
        uniswapV3FactoryAddress,
        uniswapPricingHelperAddress,
      ],
       
      
    }
  )

 
  //is this necessary ? 
  //isnt this just an implementation?
   // this is necessary so only the protocol timelock can upgrade the beacon proxy 
  
  const { protocolTimelock , protocolOwnerSafe } = await hre.getNamedAccounts()
  if (protocolTimelock === '0x0000000000000000000000000000000000000000') {
    // Same trap as the escrow beacon: this script's id is recorded whether or
    // not the transfer ran, so "run deploy again" is not something anyone can
    // actually do. The transfer lives in
    // deploy/upgrades/46_transfer_timelock_ownership.ts, which has its own id
    // and is not blocked by this one.
    hre.log('⚠️  protocolTimelock is zero address — skipping beacon ownership transfer. Run the `protocol:transfer-timelock-ownership` tag once the timelock is set.')
  } else {
    hre.log('Transferring ownership of CommitmentGroupBeacon to Gnosis Safe...')
    await commitmentGroupBeacon.transferOwnership(protocolTimelock)
    hre.log('done.')
  }

  return true
}

 

 

// tags and deployment
deployFn.id = 'lender-commitment-group-beacon-v2:deploy'
deployFn.tags = ['lender-commitment-group-beacon-v2']
deployFn.dependencies = [
  'teller-v2:deploy',
  'smart-commitment-forwarder:deploy', 
   'uniswap-pricing-helper:deploy'
]

deployFn.skip = skipUnlessChainSupports('lenderGroupsV2')
export default deployFn
