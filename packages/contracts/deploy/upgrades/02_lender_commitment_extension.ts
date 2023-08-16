import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('LenderCommitmentForwarder: Proposing upgrade...')

  const tellerV2 = await hre.contracts.get('TellerV2')
  const marketRegistry = await hre.contracts.get('MarketRegistry')
  const lenderCommitmentForwarder = await hre.contracts.get(
    'LenderCommitmentForwarder'
  )

  await hre.defender.proposeBatchTimelock(
    'Lender Commitment Forwarder Extension Upgrade',
    ` 

# LenderCommitmentForwarder

* Upgrades the lender commitment forwarder so that trusted extensions can 
`,
    [
      {
        proxy: lenderCommitmentForwarder,
        implFactory: await hre.ethers.getContractFactory(
          'LenderCommitmentForwarderWithExtensions'
        ),

        opts: {
          unsafeAllow: ['constructor', 'state-variable-immutable'],
          constructorArgs: [
            await tellerV2.getAddress(),
            await marketRegistry.getAddress()
          ]
        }
      }
    ]
  )

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-forwarder:merkle-upgrade'
deployFn.tags = [
  'proposal',
  'upgrade',
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:merkle-upgrade'
]
deployFn.dependencies = [
  'market-registry:deploy',
  'teller-v2:deploy',
  'lender-commitment-forwarder:deploy'
]
deployFn.skip = async (hre) => {
  return (
    !hre.network.live ||
    !['mainnet', 'polygon', 'arbitrum', 'goerli'].includes(hre.network.name)
  )
}
export default deployFn
