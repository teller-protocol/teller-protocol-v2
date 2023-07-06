import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('Lender Manager: Proposing upgrade...')
 
  const marketRegistry = await hre.contracts.get('MarketRegistry')
   
  const lenderManager = await hre.contracts.get('LenderManager')
  const lenderManagerArt = await hre.contracts.get('LenderManagerArt')
  
  await hre.defender.proposeBatchTimelock(
    'Lender Manager: Art Upgrade',
    `
# Lender Manager

* Updates the tokenURI function so it returns an svg image rendering with loan summary data.

`,
    [
       
      {
        proxy: lenderManager.address,
        implFactory: await hre.ethers.getContractFactory('LenderManager', {
          libraries: {
            LenderManagerArt: lenderManagerArt.address,
          }, 
        }), 
        opts: {
          unsafeAllow: ['constructor', 'state-variable-immutable','external-library-linking',],
          constructorArgs: [marketRegistry.address],
          
        },
        
      },
    
    ]
  )

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'lender-manager:upgrade-art'
deployFn.tags = [
  'proposal',
  'upgrade',
  'lender-manager',
  'lender-manager:upgrade-art',
]
deployFn.dependencies = [ 
  'market-registry:deploy', 
  'lender-manager:deploy', 
]
deployFn.skip = async (hre) => {
  return false
 
}
export default deployFn
