import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {



  const { deployer } = await hre.getNamedAccounts()

  // Deploy FixedPointQ96 library first
  const FixedPointQ96 = await hre.deployments.deploy('FixedPointQ96', {
    from: deployer,
  })

  hre.log('FixedPointQ96 library deployed at:' )
  hre.log( FixedPointQ96.address)



  // Deploy PriceAdapterAlgebra with linked library
  const PriceAdapterAlgebra = await hre.deployments.deploy('PriceAdapterAlgebra', {
    from: deployer,
    libraries: {
      FixedPointQ96: FixedPointQ96.address,
    },
  })

  hre.log('PriceAdapterAlgebra deployed at:' )
    hre.log( PriceAdapterAlgebra.address)


}

// tags and deployment
deployFn.id = 'price-adapter-algebra:deploy'
deployFn.tags = ['teller-v2', 'price-adapter-algebra:deploy']
deployFn.dependencies = []

deployFn.skip = async (hre) => {
    return !hre.network.live || ![ 'apechain' ].includes(hre.network.name)
  }

export default deployFn
