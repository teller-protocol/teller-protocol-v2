import { DeployFunction } from 'hardhat-deploy/dist/types'


import { get_ecosystem_contract_address } from "../../helpers/ecosystem-contracts-lookup" 


const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')
  const marketRegistry = await hre.contracts.get('MarketRegistry')


 let uniswapV3FactoryAddress  =  get_ecosystem_contract_address( hre.network.name, "uniswapV3Factory" ) ;
   


  const lenderCommitmentForwarderAlpha = await hre.deployProxy(
    'LenderCommitmentForwarderAlpha',
    {
      unsafeAllow: ['constructor', 'state-variable-immutable'],
      constructorArgs: [
        await tellerV2.getAddress(),
        await marketRegistry.getAddress(),
        uniswapV3FactoryAddress,
      ],
    }
  )

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-forwarder:alpha:deploy'
deployFn.tags = [
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:alpha',
  'lender-commitment-forwarder:alpha:deploy',
]
deployFn.dependencies = ['teller-v2:deploy', 'market-registry:deploy']

deployFn.skip = async (hre) => {
  return !hre.network.live || !['sepolia','polygon','mainnet','mainnet_live_fork','arbitrum','base','optimism','katana','hyperevm','bsc','apechain'].includes(hre.network.name)
}

export default deployFn
