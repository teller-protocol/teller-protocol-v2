import { DeployFunction  } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('CollateralManager: Proposing upgrade...')

  // const tellerV2 = await hre.contracts.get('TellerV2')
   
  const CollateralManager = await hre.contracts.get(
    'CollateralManager'
  )

  

  await hre.upgrades.proposeBatchTimelock({
    title: 'CollateralManager: Add Read Function',
    description: ` 
# CollateralManager
* Add a function to read the current escrow beacon address.
`,
    _steps: [
      {
        proxy: CollateralManager,
        implFactory: await hre.ethers.getContractFactory(
          'CollateralManager'
        ),

        opts: {
          unsafeAllow: [  'state-variable-immutable'],
          
           
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
deployFn.id = 'collateral-manager:upgrade-read-fn'
deployFn.tags = ['proposal', 'upgrade', 'collateral-manager:upgrade-read-fn']
deployFn.dependencies = ['collateral:manager:deploy']
deployFn.skip = async (hre) => {
  
 
  return !hre.network.live || !['sepolia' ,   'mainnet'  ].includes(hre.network.name)
}
export default deployFn

