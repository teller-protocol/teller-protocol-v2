import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('Lender pools V2: Proposing upgrade...')



  const lenderCommitmentGroupV2BeaconProxy = await hre.contracts.get('LenderCommitmentGroupBeaconV2')

  const tellerV2 = await hre.contracts.get('TellerV2')
  const SmartCommitmentForwarder = await hre.contracts.get(
    'SmartCommitmentForwarder'
  )
  const tellerV2Address = await tellerV2.getAddress()


//   const uniswapPricingLibraryV2 = await hre.contracts.get('UniswapPricingLibraryV2')
 
  const smartCommitmentForwarderAddress =
    await SmartCommitmentForwarder.getAddress()

  let uniswapV3FactoryAddress: string
  switch (hre.network.name) {
    case 'mainnet':
    case 'goerli':
    case 'arbitrum':
    case 'optimism':
    case 'polygon':
    case 'localhost':
      uniswapV3FactoryAddress = '0x1F98431c8aD98523631AE4a59f267346ea31F984'
      break
    case 'base':
      uniswapV3FactoryAddress = '0x33128a8fC17869897dcE68Ed026d694621f6FDfD'
      break
    case 'sepolia':
      uniswapV3FactoryAddress = '0x0227628f3F023bb0B980b67D528571c95c6DaC1c'
      break
    default:
      throw new Error('No swap factory address found for this network')
  }


  const uniswapPricingLibraryV2 = await hre.deployments.get('UniswapPricingLibraryV2')

 

//this is why the owner of the beacon should be timelock controller ! 
// so we can upgrade it like this . Using a proposal.  This actually goes AROUND the proxy admin, interestingly. 
  await hre.upgrades.proposeBatchTimelock({
    title: 'Lender Pools V2: Upgrade Redeem Time',
    description: ` 
# Lender Pools V2

* A patch to fix withdraw time delay requirements.
`,
    _steps: [
      {
        beacon: lenderCommitmentGroupV2BeaconProxy,
        implFactory: await hre.ethers.getContractFactory('LenderCommitmentGroup_Pool_V2', {
          libraries: {
          UniswapPricingLibraryV2:   uniswapPricingLibraryV2.address,
          },
        }),

        opts: {
          //unsafeSkipStorageCheck: true, 
          unsafeAllow: [
            'constructor',
            'state-variable-immutable',
            'external-library-linking',
          ],
          constructorArgs: [
            tellerV2Address,
            smartCommitmentForwarderAddress,
            uniswapV3FactoryAddress,

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
deployFn.id = 'lender-commitment-group-beacon-v2:upgrade-redeem-delay'
deployFn.tags = ['lender-commitment-group-beacon-v2']
deployFn.dependencies = [
  'teller-v2:deploy',
  'smart-commitment-forwarder:deploy',
  'teller-v2:uniswap-pricing-library-v2',

  'lender-commitment-group-beacon-v2:deploy'
]

deployFn.skip = async (hre) => {
  return !hre.network.live || !['sepolia'].includes(hre.network.name)
}
export default deployFn
