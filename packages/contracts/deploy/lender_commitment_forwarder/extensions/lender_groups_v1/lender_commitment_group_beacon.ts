 


import { DeployFunction } from 'hardhat-deploy/dist/types'

import { UpgradeableBeacon } from 'types/typechain'


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

  let uniswapV3FactoryAddress: string
  switch (hre.network.name) {
    case 'mainnet':
    case 'mainnet_live_fork':
    case 'goerli':
    case 'arbitrum':
    case 'optimism':
    case 'polygon':
    case 'localhost':
      uniswapV3FactoryAddress = '0x1F98431c8aD98523631AE4a59f267346ea31F984'
      break
    case 'base':
      uniswapV3FactoryAddress = '0x33128a8fC17869897dcE68Ed026d694621f6FDfD'
      break
    case 'sepolia':
      uniswapV3FactoryAddress = '0x0227628f3F023bb0B980b67D528571c95c6DaC1c'
      break
    default:
      throw new Error('No swap factory address found for this network')
  }

 


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
]

deployFn.skip = async (hre) => {
  return !hre.network.live || !['sepolia', 'polygon' , 'mainnet','mainnet_live_fork','arbitrum','base'].includes(hre.network.name)
}
export default deployFn
