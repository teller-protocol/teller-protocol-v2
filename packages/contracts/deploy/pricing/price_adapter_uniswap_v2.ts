import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {



  const { deployer } = await hre.getNamedAccounts()

  // Deploy FixedPointQ96 library first
  const FixedPointQ96 = await hre.deployments.deploy('FixedPointQ96', {
    from: deployer,
  })

  hre.log('FixedPointQ96 library deployed at:' )
  hre.log( FixedPointQ96.address)



  // need to add a delay , wait here ! 
   // await tx.wait(1) // wait one block

 
  const PriceAdapterUniswapV2 = await hre.deployments.deploy('PriceAdapterUniswapV2', {
    from: deployer,
    libraries: {
      FixedPointQ96: FixedPointQ96.address,
    },
  })

  hre.log('PriceAdapterUniswapV2 deployed at:' )
    hre.log( PriceAdapterUniswapV2.address)


}

// tags and deployment
deployFn.id = 'price-adapter-uniswap-v2:deploy'
deployFn.tags = ['teller-v2', 'price-adapter-uniswap-v2:deploy']
deployFn.dependencies = []

deployFn.skip = async (hre) => {
    return !hre.network.live || ![  'base', ].includes(hre.network.name)
  }

export default deployFn