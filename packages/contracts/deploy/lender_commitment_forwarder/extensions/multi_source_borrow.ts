import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const { deployer } = await hre.getNamedAccounts()

  const tellerV2 = await hre.contracts.get('TellerV2')

  const multiSourceBorrow = await hre.deploy('MultiSourceBorrow', {
    from: deployer,
    args: [
      await tellerV2.getAddress(),
    ],
    log: true,
    skipIfAlreadyDeployed: true,
  })

  console.log('MultiSourceBorrow deployed at:', multiSourceBorrow.address)

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
