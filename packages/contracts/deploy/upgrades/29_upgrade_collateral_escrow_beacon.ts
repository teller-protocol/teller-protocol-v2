import { DeployFunction  } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('CollateralEscrowV1: Proposing upgrade...')

  // const tellerV2 = await hre.contracts.get('TellerV2')
   
  const CollateralManager = await hre.contracts.get(
    'CollateralManager'
  )

  /*
   let collateralEscrowLegacyAddress = "0x27f57e6E919EB8fa8EA8f64a45dD425C70d3Ad44";
  let collateralEscrowLegacyImpl = await hre.ethers.getContractFactory('CollateralEscrowV1', {}  );

  const constructorArgs = [   ]; 


 let force_import =   await hre.upgrades.forceImport( collateralEscrowLegacyAddress, collateralEscrowLegacyImpl, { constructorArgs } );
 */

  const collateralEscrowBeaconProxy = await hre.contracts.get('CollateralEscrowBeacon')


  await hre.upgrades.proposeBatchTimelock({
    title: 'CollateralEscrowV1: Withdraw dust',
    description: ` 
# CollateralEscrowV1

* A patch to add fn for owner to withdraw dust 
`,
    _steps: [
      {
        beacon: collateralEscrowBeaconProxy,
        implFactory: await hre.ethers.getContractFactory('CollateralEscrowV1' ),

        opts: {
          unsafeSkipStorageCheck: true, 
          unsafeAllow: [ 
            'state-variable-immutable', 
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
deployFn.id = 'collateral-escrow:upgrade-beacon-dust'
deployFn.tags = ['proposal', 'upgrade', 'collateral-escrow:upgrade-beacon-dust']
deployFn.dependencies = ['collateral:escrow-beacon:deploy']
deployFn.skip = async (hre) => {
  
 
  return !hre.network.live || ![ 'mainnet'  ].includes(hre.network.name)
}
export default deployFn

