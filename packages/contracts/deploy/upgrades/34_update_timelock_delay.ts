import { DeployFunction } from 'hardhat-deploy/dist/types'




const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('Timelock Delay Update')

  const networkName = hre.network.name

 
   const { protocolTimelock } = await hre.getNamedAccounts()

  await hre.upgrades.proposeBatchTimelock({
    title: 'Update Timelock Delay',
    description: ` 
# Update Timelock Delay to 2 hours
 
`,
    _steps: [
      {
         contractAddress: protocolTimelock, 
          contractImplementation: await hre.ethers.getContractFactory('TimelockController'),


        callFn: "updateDelay",
        callArgs: [7200],

        
       
      },
    ],
  })

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'timelock-controller:update-delay-7200'
deployFn.tags = [
  'proposal',
  'upgrade',
  'timelock-controller',
  'timelock-controller:update-delay', 
]
deployFn.dependencies = [
  'teller-v2:deploy', 
]
deployFn.skip = async (hre) => {
  return !(
    hre.network.live &&
    [ 'goerli', 'sepolia', 'katana', 'optimism', 'base', 'mainnet','arbitrum','polygon'].includes(
      hre.network.name
    )
  )
}
export default deployFn
