import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')
  const SmartCommitmentForwarder = await hre.contracts.get(
    'SmartCommitmentForwarder'
  )

  const smartCommitmentForwarderAddress =
    await SmartCommitmentForwarder.getAddress()

  //for sepolia
  const uniswapV3FactoryAddress = '0x1F98431c8aD98523631AE4a59f267346ea31F984'

  const networkName = hre.network.name

  const lenderCommitmentGroupSmart = await hre.deployProxy(
    'LenderCommitmentGroup_Smart',
    {
      unsafeAllow: ['constructor', 'state-variable-immutable'],
      constructorArgs: [
        smartCommitmentForwarderAddress,
        uniswapV3FactoryAddress
      ]
    }
  )

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-forwarder:extensions:flash-rollover:deploy'
deployFn.tags = ['lender-commitment-group-smart']
deployFn.dependencies = [
  'teller-v2:deploy',
  'smart-commitment-forwarder:deploy'
]

deployFn.skip = async (hre) => {
  return !hre.network.live
}
export default deployFn
