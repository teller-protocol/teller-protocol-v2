import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const deployer = await hre.getNamedSigner('deployer')

  const tellerV2 = await hre.contracts.get('TellerV2')

  hre.log('Deploying MultiSourceBorrow...')
  hre.log('Network name:')
  hre.log(hre.network.name)

  hre.log('Deployer:')
  hre.log(deployer.address)

  hre.log('TellerV2 address:')
  let tellerV2Address = await tellerV2.getAddress()
  hre.log(tellerV2Address)

  const multiSourceBorrow = await hre.deployProxy('MultiSourceBorrow', {
    initializer: 'initialize',
    constructorArgs: [],
  }, [tellerV2Address])

  hre.log('MultiSourceBorrow deployed at:', await multiSourceBorrow.getAddress())

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-forwarder:extensions:multi-source-borrow:deploy'
deployFn.tags = [
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:extensions',
  'lender-commitment-forwarder:extensions:deploy',
  'lender-commitment-forwarder:extensions:multi-source-borrow',
  'lender-commitment-forwarder:extensions:multi-source-borrow:deploy',
]
deployFn.dependencies = [
  'teller-v2:deploy',
]

 
deployFn.skip = async (hre) => {
  
 
  return !hre.network.live || !['sepolia' ,   'base' ].includes(hre.network.name)
}


export default deployFn
