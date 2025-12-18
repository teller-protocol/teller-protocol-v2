import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('Smart Commitment Forwarder: Proposing upgrade...')

  const tellerV2 = await hre.contracts.get('TellerV2')
  const marketRegistry = await hre.contracts.get('MarketRegistry')

 

  const smartCommitmentForwarder = await hre.contracts.get(
    'SmartCommitmentForwarder'
  )

  await hre.upgrades.proposeBatchTimelock({
    title: 'Smart Commitment Forwarder: Upgrade',
    description: ` 
# Smart Commitment Forwarder
* Modifies Smart Commitment Forwarder to upgrade the context forwarder.
`,
    _steps: [
      {
        proxy: smartCommitmentForwarder,
        implFactory: await hre.ethers.getContractFactory(
          'SmartCommitmentForwarder'
        ),

        opts: {
          unsafeAllow: ['constructor', 'state-variable-immutable'],
          unsafeAllowRenames: true,
          // unsafeSkipStorageCheck: true, //caution !
          constructorArgs: [
            await tellerV2.getAddress(),
            await marketRegistry.getAddress(),
          ],
           initializer : "initialize"   //will this run on the new upgrade ? 
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
deployFn.id = 'smart-commitment-forwarder:upgrade-context-forwarding'
deployFn.tags = ['proposal', 'upgrade', 'smart-commitment-forwarder-upgrade-context-forwarding']
deployFn.dependencies = ['smart-commitment-forwarder:deploy']
deployFn.skip = async (hre) => {
  //  return true // ALWAYS SKIP FOR NOW
  return !hre.network.live || !['goerli','polygon' ].includes(hre.network.name)
}
export default deployFn
