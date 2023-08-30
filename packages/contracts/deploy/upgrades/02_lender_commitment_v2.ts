import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('LenderCommitmentForwarder V2: Proposing upgrade...')

  const tellerV2 = await hre.contracts.get('TellerV2')
  const marketRegistry = await hre.contracts.get('MarketRegistry')
  const lenderCommitmentForwarder = await hre.contracts.get(
    'LenderCommitmentForwarder'
  )

  const namedAccounts = await hre.getNamedAccounts()

  const { protocolTimelock } = namedAccounts

  const lenderCommitmentForwarderV2Factory =
    await hre.ethers.getContractFactory('LenderCommitmentForwarder_V2')

  const rolloverContract = await hre.contracts.get('FlashRolloverLoan')

  const rolloverContractAddress = await rolloverContract.getAddress()

  console.log({
    protocolTimelock
  })

  const lenderCommitmmentForwarderAddress =
    await lenderCommitmentForwarder.getAddress()

  await hre.defender.proposeBatchTimelock({
    title: 'Lender Commitment Forwarder Extension Upgrade',
    description: ` 

# LenderCommitmentForwarder_V2

* Upgrades the lender commitment forwarder so that trusted extensions can specify a specific recipient
`,
    _steps: [
      {
        proxy: lenderCommitmmentForwarderAddress,
        implFactory: await hre.ethers.getContractFactory(
          'LenderCommitmentForwarder_V2'
        ),

        opts: {
          unsafeAllow: ['constructor', 'state-variable-immutable'],
          constructorArgs: [
            await tellerV2.getAddress(),
            await marketRegistry.getAddress()
          ],

          //call initialize

          call: {
            fn: 'initialize',
            args: [protocolTimelock]
          }
        }
      },
      //protocol timelock adds an extension
      {
        contractAddress: await lenderCommitmentForwarder.getAddress(),
        contractImplementation: lenderCommitmentForwarderV2Factory,
        callFn: 'addExtension',
        callArgs: [rolloverContractAddress]
      }
    ]
  })

  /*
  const callTitle = 'Add Extension: Rollover Contract Address'
  const callDescription = `
    Adds the rollover contract as an extension to the Lender Commitment Forwarder V2 
  `*/
  /*
  await hre.defender.proposeCall(
    await lenderCommitmentForwarder.getAddress(),
    lenderCommitmentForwarderV2Factory,
    'addExtension',
    [rolloverContractAddress],
    callTitle,
    callDescription
  )*/

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-forwarder:v2-upgrade'
deployFn.tags = [
  'proposal',
  'upgrade',
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:v2-upgrade'
]
deployFn.dependencies = [
  'market-registry:deploy',
  'teller-v2:deploy',
  'lender-commitment-forwarder:deploy',
  'commitment-rollover-loan:deploy'
]
deployFn.skip = async (hre) => {
  return (
    !hre.network.live ||
    !['mainnet', 'polygon', 'arbitrum', 'goerli', 'sepolia'].includes(
      hre.network.name
    )
  )
}
export default deployFn
