import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {



  const { deployer } = await hre.getNamedAccounts()

  // Deploy FixedPointQ96 library first
  const FixedPointQ96 = await hre.deployments.deploy('FixedPointQ96', {
    from: deployer,
  })

  hre.log('FixedPointQ96 library deployed at:' )
  hre.log( FixedPointQ96.address)




  // Wait for one block confirmation
  if (FixedPointQ96.receipt) {
    await hre.ethers.provider.waitForTransaction(FixedPointQ96.receipt.transactionHash, 1)
  }



  // Deploy PriceAdapterAerodrome with linked library
  const PriceAdapterUniswapV3 = await hre.deployments.deploy('PriceAdapterUniswapV3', {
    from: deployer,
    libraries: {
      FixedPointQ96: FixedPointQ96.address,
    },
  })

  hre.log('PriceAdapterUniswapV3 deployed at:' )
    hre.log( PriceAdapterUniswapV3.address)


}

// tags and deployment
deployFn.id = 'price-adapter-uniswap-v3:deploy'
deployFn.tags = ['teller-v2', 'price-adapter-uniswap-v3:deploy']
deployFn.dependencies = []

deployFn.skip = async (hre) => {
    return !hre.network.live || ![  'base', ].includes(hre.network.name)
  }

export default deployFn