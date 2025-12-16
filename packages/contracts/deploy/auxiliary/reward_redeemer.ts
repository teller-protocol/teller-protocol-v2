import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const rewardRedeemer = await hre.deployProxy(
    'RewardRedeemer',
    {
      initializer: 'initialize',
      initArgs: [],
      unsafeAllow: ['constructor', 'state-variable-immutable'],
    }
  )

  return true
}

// tags and deployment
deployFn.id = 'reward-redeemer:deploy'
deployFn.tags = ['reward-redeemer:deploy']
deployFn.dependencies = [
   
]
export default deployFn
