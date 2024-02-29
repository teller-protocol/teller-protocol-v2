import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('LenderCommitmentForwarderStaging: Performing upgrade...')

  const chainId = await hre.getChainId()

  /*
  const contracts: {
    LenderCommitmentForwarder: { address: string; abi: {} }
    LenderCommitmentForwarderStaging?: { address: string; abi: {} }
    TellerV2: { address: string; abi: {} }
  } = teller_contracts[chainId as keyof typeof teller_contracts].contracts

  if (!contracts.LenderCommitmentForwarderStaging) {
    console.log('No LCF Staging contract found for this network')
    return false
  }*/

  let uniswapFactoryAddress: string
  switch (hre.network.name) {
    case 'mainnet':
    case 'goerli':
    case 'arbitrum':
    case 'optimism':
    case 'polygon':
    case 'localhost':
      uniswapFactoryAddress = '0x1F98431c8aD98523631AE4a59f267346ea31F984'
      break
    case 'base':
      uniswapFactoryAddress = '0x33128a8fC17869897dcE68Ed026d694621f6FDfD'
      break
    case 'sepolia':
      uniswapFactoryAddress = '0x0227628f3F023bb0B980b67D528571c95c6DaC1c'
      break
    default:
      throw new Error('No swap factory address found for this network')
  }

  const tellerV2 = await hre.contracts.get('TellerV2')

  const marketRegistry = await hre.contracts.get('MarketRegistry')

  const lenderCommitmentForwarderStaging = await hre.contracts.get(
    'LenderCommitmentForwarderStaging'
  )

  let tellerV2ProxyAddress = await tellerV2.getAddress()
  let marketRegistryProxyAddress = await marketRegistry.getAddress()
  let lcfStagingProxyAddress =
    await lenderCommitmentForwarderStaging.getAddress()

  const LenderCommitmentForwarderStagingImplementation =
    await hre.ethers.getContractFactory('LenderCommitmentForwarderStaging')

  const upgrade = await hre.upgrades.upgradeProxy(
    lcfStagingProxyAddress,
    LenderCommitmentForwarderStagingImplementation,
    {
      unsafeAllow: ['state-variable-immutable', 'constructor'],
      constructorArgs: [
        tellerV2ProxyAddress,
        marketRegistryProxyAddress,
        uniswapFactoryAddress
      ]
    }
  )

  hre.log('done.')
  hre.log('')
  hre.log('----------')

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-forwarder:staging:upgrade'
deployFn.tags = [
  'proposal',
  'upgrade',
  'lender-commitment-forwarder:staging',
  'lender-commitment-forwarder:staging:upgrade'
]
deployFn.dependencies = ['lender-commitment-forwarder:staging:deploy']
deployFn.skip = async (hre) => {
  return true
  return (
    !hre.network.live ||
    ![
      'localhost',
      'mainnet',
      'polygon',
      'goerli',
      'sepolia',
      'arbitrum'
    ].includes(hre.network.name)
  )
}
export default deployFn
