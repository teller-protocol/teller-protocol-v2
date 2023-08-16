import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('LenderCommitmentForwarder V2: Proposing upgrade...')

  const tellerV2 = await hre.contracts.get('TellerV2')
  const marketRegistry = await hre.contracts.get('MarketRegistry')
  const lenderCommitmentForwarder = await hre.contracts.get(
    'LenderCommitmentForwarder_V1'
  )

  const namedAccounts = await hre.getNamedAccounts();

  const {protocolTimelock} = namedAccounts;

  await hre.defender.proposeBatchTimelock(
    'Lender Commitment Forwarder Extension Upgrade',
    ` 

# LenderCommitmentForwarder_V2

* Upgrades the lender commitment forwarder so that trusted extensions can specify a specific recipient
`,
    [
      {
        proxy: lenderCommitmentForwarder,
        implFactory: await hre.ethers.getContractFactory(
          'LenderCommitmentForwarder_V2'
        ),

        opts: {
          unsafeAllow: ['constructor', 'state-variable-immutable'],
          constructorArgs: [
            await tellerV2.getAddress(),
            await marketRegistry.getAddress()
          ],

          //need to initialize
          // will this work ?  
          call: {
            fn: 'initializeExtension',
            args: [protocolTimelock]
          }

        }
      }
    ]
  )
 
  let lenderCommitmentForwarderV2Factory = await hre.ethers.getContractFactory(
    'LenderCommitmentForwarder_V2'
  );
  
  const rolloverContractAddress = await hre.ethers.getContractFactory(
    'CommitmentRolloverLoan'
  );

  const callTitle ="Add Extension: Rollover Contract Address"
  const callDescription = `
    Adds the rollover contract as an extension to the Lender Commitment Forwarder V2 
  `;

  await hre.defender.proposeCall(
    await lenderCommitmentForwarder.getAddress(),
    lenderCommitmentForwarderV2Factory, 
    'addExtension',
    [rolloverContractAddress],
    callTitle,
    callDescription 

  ) 
 


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
  'lender-commitment-forwarder:deploy'
]
deployFn.skip = async (hre) => {
  return (
    !hre.network.live ||
    !['mainnet', 'polygon', 'arbitrum', 'goerli'].includes(hre.network.name)
  )
}
export default deployFn
