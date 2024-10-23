import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('LoanReferralForwarder: Proposing upgrade...')

  const chainId = await hre.getChainId()
 

  const tellerV2 = await hre.contracts.get('TellerV2')
 
  const LoanReferralForwarder = await hre.contracts.get(
    'LoanReferralForwarder'
  )

  const tellerV2ProxyAddress = await tellerV2.getAddress()
 
  const LoanReferralForwarderImplementation =
    await hre.ethers.getContractFactory('LoanReferralForwarder')
 
    const proxyAddress = await LoanReferralForwarder.getAddress()
 

 
  await hre.upgrades.proposeBatchTimelock({
    title: 'LoanReferralForwarder: Upgrade',
    description: ` 
# LoanReferralForwarder

* Upgrade to add event emits.
`,
    _steps: [
      {
        proxy: proxyAddress,
        implFactory: LoanReferralForwarderImplementation,

        opts: {
          unsafeAllow: ['constructor', 'state-variable-immutable'],

          constructorArgs: [
            tellerV2ProxyAddress 
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
deployFn.id = 'loan-referral-forwarder:upgrade_1'
deployFn.tags = [
  'proposal',
  'upgrade',
  'loan-referral-forwarder',
  'loan-referral-forwarder:upgrade_1',
]
deployFn.dependencies = ['lender-commitment-forwarder:extensions:loan-referral-forwarder:deploy']
deployFn.skip = async (hre) => {
  return (
    !hre.network.live ||
    ![
      'localhost',
      'polygon',
      'arbitrum',
      'base',
      'mainnet',
      'sepolia'  
      
    ].includes(hre.network.name)
  )
}
export default deployFn
