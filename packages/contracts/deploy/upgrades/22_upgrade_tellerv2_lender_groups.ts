import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('TellerV2 LenderGroups: Proposing upgrade...')

  const trustedForwarder = await hre.contracts.get('MetaForwarder')
  const v2Calculations = await hre.deployments.get('V2Calculations')
  const tellerV2 = await hre.contracts.get('TellerV2')
  const marketRegistry = await hre.contracts.get('MarketRegistry') 
  const escrowVault = await hre.contracts.get('EscrowVault')
  const collateralManager = await hre.contracts.get('CollateralManager')
  const collateralEscrowBeacon = await hre.contracts.get(
    'CollateralEscrowBeacon'
  )
  const lenderManager = await hre.contracts.get('LenderManager')
 /* const lenderCommitmentForwarder = await hre.contracts.get(
    'LenderCommitmentForwarder'
  )
*/

  const protocolPausingManager = await hre.contracts.get('ProtocolPausingManager')
  

  var tellerV2Call = {
            fn: 'setProtocolPausingManager',
            args: [await protocolPausingManager.getAddress()],
   };

  //already initialized on polygon 
  if ([  'polygon' ].includes(hre.network.name) ) {
    tellerV2Call = undefined ; 

    console.log("  ===== skipping reinitializer for tellerV2 =====");
  }else{
    console.log("  ===== calling reinitializer for tellerV2 =====");
  }


  await hre.upgrades.proposeBatchTimelock({
    title: 'TellerV2 LenderGroups Upgrade',
    description: `


  # This proposal upgrades the following contracts:

  # Market Registry
  # TellerV2  + V2Calculations + ProtocolFee  
  # CollateralManager 
  # CollateralEscrowV1
   
  # In order to do so, it requires these new contracts to have already been deployed on the network: 

   
  # Smart Commitment Forwarder 
  # Lender Commitment Group Beacon
  # Lender Commitment Group Factory 
  # Protocol Pausing Manager 
  # Hypernative Oracle (optional)


`,
    _steps: [
      {
        proxy: marketRegistry,
        implFactory: await hre.ethers.getContractFactory('MarketRegistry'),
      },

      
      {
        proxy: tellerV2,
        implFactory: await hre.ethers.getContractFactory('TellerV2', {
          libraries: {
            V2Calculations: v2Calculations.address,
          },
        }),

        opts: {
            unsafeSkipStorageCheck: true, // this is due to the HasProtocolPausingManager which we have tested to not break storage slots 
          unsafeAllow: [
            'constructor',
            'state-variable-immutable',
            'external-library-linking',
          ],
          constructorArgs: [await trustedForwarder.getAddress()],

          call:  tellerV2Call ,
        },
      },
      {
        proxy: collateralManager,
        implFactory: await hre.ethers.getContractFactory('CollateralManager'),
      },
      {
        beacon: collateralEscrowBeacon,
        implFactory: await hre.ethers.getContractFactory('CollateralEscrowV1'),
      },
     
    ],
  })

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'lender-groups:upgrade'
deployFn.tags = [
  'proposal',
  'upgrade',
  'lender-groups',
  'lender-groups:upgrade',
]
deployFn.dependencies = [ 
  
  'protocol-pausing-manager:deploy',
  'market-registry:deploy',
  'teller-v2:v2-calculations',
  'teller-v2:init',
  'smart-commitment-forwarder:deploy',
  'lender-commitment-group-factory:deploy',
]
deployFn.skip = async (hre) => {
  return (
    !hre.network.live ||
    ![  'mainnet', 'arbitrum', 'base', 'polygon', 'goerli' ].includes(hre.network.name)
  )
}
export default deployFn
