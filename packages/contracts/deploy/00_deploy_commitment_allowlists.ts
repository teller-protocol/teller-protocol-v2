import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'

const deployFn: DeployFunction = async (hre) => {


 // const tellerV2 = await hre.contracts.get('TellerV2')
  const lenderCommitmentForwarder = await hre.contracts.get('LenderCommitmentForwarder')
 


  await deploy({
    contract: 'EnumerableSetAllowlist',
    args: [ lenderCommitmentForwarder.address ],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      
    },
    skipIfAlreadyDeployed: true,
    hre,
  })

  await deploy({
    contract: 'OpenAllowlist',
    args: [  ],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
       
    },
    skipIfAlreadyDeployed: true,
    hre,
  })
}

// tags and deployment
deployFn.tags = ['commitment-allowlists']
deployFn.dependencies = ['teller-v2']
export default deployFn
