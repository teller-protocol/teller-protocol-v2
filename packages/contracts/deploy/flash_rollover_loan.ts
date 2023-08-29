import { DeployFunction } from 'hardhat-deploy/dist/types'

//feel free to add more ..
const aavePoolAddressProvider: { [networkName: string]: string } = {
  mainnet: '0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e',
  goerli: '0xC911B590248d127aD18546B186cC6B324e99F02c',
  sepolia: '0x0496275d34753A48320CA58103d5220d394FF77F',
  polygon: '0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb'
}

const networksWithAave: string[] = Object.keys(aavePoolAddressProvider)

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')
  const lenderCommitmentForwarder = await hre.contracts.get(
    'LenderCommitmentForwarder'
  )

  const networkName = hre.network.name

  const flashRolloverLoan = await hre.deployProxy('FlashRolloverLoan', {
    unsafeAllow: ['constructor', 'state-variable-immutable'],
    constructorArgs: [
      await tellerV2.getAddress(),
      await lenderCommitmentForwarder.getAddress(),
      aavePoolAddressProvider[networkName]
    ]
  })

  return true
}

// tags and deployment
deployFn.id = 'flash-rollover-loan:deploy'
deployFn.tags = ['flash-rollover-loan', 'flash-rollover-loan:deploy']
deployFn.dependencies = [
  'teller-v2:deploy',
  'lender-commitment-forwarder:deploy'
]

deployFn.skip = async (hre) => {
  return !hre.network.live || !networksWithAave.includes(hre.network.name)
}
export default deployFn
