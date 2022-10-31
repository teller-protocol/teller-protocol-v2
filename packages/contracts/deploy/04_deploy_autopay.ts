import { getNamedSigner } from 'hardhat'
import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')

  const autopayFee = 5 // 0.05%
  const newOwner = await getNamedSigner('deployer')

  await deploy({
    contract: 'TellerV2Autopay',
    args: [tellerV2.address],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init: {
          methodName: 'initialize',
          args: [autopayFee, await newOwner.getAddress()],
        },
      },
    },
    skipIfAlreadyDeployed: true,
    hre,
  })
}

// tags and deployment
deployFn.tags = ['autopay']
deployFn.dependencies = ['teller-v2']
export default deployFn
