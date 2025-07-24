import { DeployFunction  } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('Loan Referral Forwarder V2: Proposing upgrade...')

  const tellerV2 = await hre.contracts.get('TellerV2')
  
  
  const LoanReferralForwarderV2 = await hre.contracts.get(
    'LoanReferralForwarderV2'
  )

 
/*
  let scfLegacyAddress = "0x0AeeeD450EcCaFaA140222De43963B179B514540";
  let scfLegacyImpl = await hre.ethers.getContractFactory('SmartCommitmentForwarder', {}  );

  const constructorArgs = [
            await tellerV2.getAddress(),
            await marketRegistry.getAddress(),
          ]; 


 let force_import =   await hre.upgrades.forceImport( scfLegacyAddress, scfLegacyImpl, { constructorArgs } );
 
 */

  await hre.upgrades.proposeBatchTimelock({
    title: 'LoanReferralForwarderV2: Upgrade SafeTransfer',
    description: ` 
# LoanReferralForwarderV2
* Modifies SafeTransfer to work with more valid ERC20 tokens .
`,
    _steps: [
      {
        proxy: LoanReferralForwarderV2,
        implFactory: await hre.ethers.getContractFactory(
          'LoanReferralForwarderV2'
        ),

        opts: {
          unsafeAllow: ['constructor', 'state-variable-immutable'],
          // unsafeAllowRenames: true,
          // unsafeSkipStorageCheck: true, //caution !
          constructorArgs: [
            await tellerV2.getAddress(),
            
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
deployFn.id = 'lender-commitment-forwarder-v2:upgrade-transfer'
deployFn.tags = ['proposal', 'upgrade', 'lender-commitment-forwarder-v2-upgrade-transfer']
deployFn.dependencies = ['lender-commitment-forwarder:extensions:loan-referral-forwarder-v2:deploy']
deployFn.skip = async (hre) => {
  
 
  return !hre.network.live || !['sepolia' ,   'base', 'polygon','optimism'].includes(hre.network.name)
}
export default deployFn

