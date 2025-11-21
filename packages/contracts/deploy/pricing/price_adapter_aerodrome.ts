import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {



  const { deployer } = await hre.getNamedAccounts()

  // Deploy FixedPointQ96 library first
  const FixedPointQ96 = await hre.deployments.deploy('FixedPointQ96', {
    from: deployer,
  })

  hre.log('FixedPointQ96 library deployed at:' )
  hre.log( FixedPointQ96.address)

  


  // Deploy PriceAdapterAerodrome with linked library
  const PriceAdapterAerodrome = await hre.deployments.deploy('PriceAdapterAerodrome', {
    from: deployer,
    libraries: {
      FixedPointQ96: FixedPointQ96.address,
    },
  })

  hre.log('PriceAdapterAerodrome deployed at:' )
    hre.log( PriceAdapterAerodrome.address)


}

// tags and deployment
deployFn.id = 'price-adapter-aerodrome:deploy'
deployFn.tags = ['teller-v2', 'price-adapter-aerodrome:deploy']
deployFn.dependencies = []

deployFn.skip = async (hre) => {
    return !hre.network.live || ![  'base', ].includes(hre.network.name)
  }

export default deployFn