import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {

    

  const { deployer } = await hre.getNamedAccounts()
  const PriceAdapterAerodrome = await hre.deployments.deploy('PriceAdapterAerodrome', {
    from: deployer,
  })

  hre.log('Deploying PriceAdapterAerodrome')


}

// tags and deployment
deployFn.id = 'price-adapter-aerodrome:deploy'
deployFn.tags = ['teller-v2', 'price-adapter-aerodrome:deploy']
deployFn.dependencies = ['']

deployFn.skip = async (hre) => {
    return !hre.network.live || ![  'base', ].includes(hre.network.name)
  }

export default deployFn