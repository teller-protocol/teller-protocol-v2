import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const { deployer } = await hre.getNamedAccounts()

  // Deploy FixedPointQ96 library first (reused if already deployed)
  const FixedPointQ96 = await hre.deployments.deploy('FixedPointQ96', {
    from: deployer,
  })

  hre.log('FixedPointQ96 library deployed at:')
  hre.log(FixedPointQ96.address)

  // Deploy the corrected Aerodrome adapter with linked library
  const PriceAdapterAerodromeV2 = await hre.deployments.deploy(
    'PriceAdapterAerodromeV2',
    {
      from: deployer,
      libraries: {
        FixedPointQ96: FixedPointQ96.address,
      },
    }
  )

  hre.log('PriceAdapterAerodromeV2 deployed at:')
  hre.log(PriceAdapterAerodromeV2.address)
}

// tags and deployment
deployFn.id = 'price-adapter-aerodrome-v2:deploy'
deployFn.tags = ['teller-v2', 'price-adapter-aerodrome-v2:deploy']
deployFn.dependencies = []

deployFn.skip = async (hre) => {
  return !hre.network.live || !['base'].includes(hre.network.name)
}

export default deployFn
