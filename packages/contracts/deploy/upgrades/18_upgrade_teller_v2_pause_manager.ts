import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('TellerV2: Proposing upgrade...')

  const tellerV2 = await hre.contracts.get('TellerV2')
  const trustedForwarder = await hre.contracts.get('MetaForwarder')
  const v2Calculations = await hre.deployments.get('V2Calculations')


  const protocolPausingManager = await hre.contracts.get('ProtocolPausingManager')
/*
wont work due to arg ? 

  let tellerV2LegacyAddress = "0xd177f4b8e348b4c56c2ac8e03b58e41b79351a7f";
  let tellerV2LegacyImpl = await hre.ethers.getContractFactory('TellerV2Legacy',
    {
      libraries: {
        V2Calculations: v2Calculations.address,
      },
    }
  );

  await hre.upgrades.forceImport(

    tellerV2LegacyAddress,
    tellerV2LegacyImpl,
    
  );
*/


  await hre.upgrades.proposeBatchTimelock({
    title: 'TellerV2: Add Pause Manager',
    description: ` 
# TellerV2

* Adds pausing manager contract link.
`,
    _steps: [
      {
        proxy: tellerV2,
        implFactory: await hre.ethers.getContractFactory('TellerV2', {
          libraries: {
            V2Calculations: v2Calculations.address,
          },
        }),

        opts: {
         // unsafeSkipStorageCheck: true, 
          unsafeAllow: [
            'constructor',
            'state-variable-immutable',
            'external-library-linking',
          ],
          constructorArgs: [await trustedForwarder.getAddress()],
        },
      },

      {
        contractAddress: await tellerV2.getAddress(),
        contractImplementation: await hre.ethers.getContractFactory('TellerV2', {
          libraries: {
            V2Calculations: v2Calculations.address,
          },
        }),
        callFn: "setProtocolPausingManager",
        callArgs: [await protocolPausingManager.getAddress()]
      }
    ],
  })


  //need to reinitialize ! 

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'teller-v2:pausing-manager-upgrade'
deployFn.tags = [
  'proposal',
  'upgrade',
  'teller-v2',
  'teller-v2:pausing-upgrade',
]
deployFn.dependencies = ['teller-v2:deploy','protocol-pausing-manager:deploy']
deployFn.skip = async (hre) => {
  return !hre.network.live || !['goerli', 'polygon'].includes(hre.network.name)
}
export default deployFn
