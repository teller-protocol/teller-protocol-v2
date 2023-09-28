import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('FlashRolloverLoan G3: Proposing upgrade...')

  const tellerV2 = await hre.contracts.get('TellerV2')
  const marketRegistry = await hre.contracts.get('MarketRegistry')
  const lenderCommitmentForwarder = await hre.contracts.get(
    'FlashRolloverLoan'
  )

  await hre.defender.proposeBatchTimelock({
    title: 'Flash Rollover Loan Extension Upgrade',
    description: ` 
# FlashRolloverLoan G3 (Extensions Upgrade)

* Upgrades the flash rollover loan contract to support merkle proofs.
`,
    _steps: [
      {
        proxy: lenderCommitmentForwarder,
        implFactory: await hre.ethers.getContractFactory(
          'FlashRolloverLoan'
        ),

        opts: {
          unsafeAllow: ['constructor', 'state-variable-immutable'],
          constructorArgs: [
            await tellerV2.getAddress(),
            await marketRegistry.getAddress(),
          ],
        },
      },
    ],
  })

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'flash-rollover:g3-upgrade'
deployFn.tags = [
  'proposal',
  'upgrade',
  'flash-rollover',
  'flash-rollover:g3-upgrade',
]
deployFn.dependencies = [
  'lender-commitment-forwarder:extensions:flash-rollover:deploy',
  'lender-commitment-forwarder:deploy',
]
deployFn.skip = async (hre) => {
  
  return !(
    hre.network.live &&
    ['mainnet', 'polygon', 'arbitrum', 'goerli', 'sepolia'].includes(
      hre.network.name
    )
  )
}
export default deployFn
