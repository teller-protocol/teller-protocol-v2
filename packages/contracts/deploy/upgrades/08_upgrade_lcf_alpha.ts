import { DeployFunction } from 'hardhat-deploy/dist/types'

const deployFn: DeployFunction = async (hre) => {
  hre.log('----------')
  hre.log('')
  hre.log('LenderCommitmentForwarderAlpha: Performing upgrade...')

  //const chainId = await hre.getChainId()
 

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


  hre.log(   
     ' hello 1 '  )


  const tellerV2 = await hre.contracts.get('TellerV2')

  const marketRegistry = await hre.contracts.get('MarketRegistry')

  const lenderCommitmentForwarderAlpha = await hre.contracts.get(
    'LenderCommitmentForwarderAlpha'
  )


  hre.log(   
    ' hello 2 '  )


  hre.log(   await tellerV2.getAddress()   )
  hre.log(   await marketRegistry.getAddress()   )
  hre.log(   await lenderCommitmentForwarderAlpha.getAddress()  )
  
  
    //failing here 
  let tellerV2ProxyAddress = await tellerV2.getAddress()
  let marketRegistryProxyAddress = await marketRegistry.getAddress()
  let lcfAlphaProxyAddress =
    await lenderCommitmentForwarderAlpha.getAddress()

  const LenderCommitmentForwarderAlphaImplementation =
    await hre.ethers.getContractFactory('LenderCommitmentForwarderAlpha')

    
  hre.log(   
    ' hello 3 '  )

 
  await hre.upgrades.proposeBatchTimelock({
    title: 'LenderCommitmentForwarderAlpha: Upgrade',
    description: ` 
# LenderCommitmentForwarderAlpha

*   Upgrade contract.
`,
    _steps: [
      {
        proxy: lcfAlphaProxyAddress,
        implFactory: LenderCommitmentForwarderAlphaImplementation,

        opts: {
          unsafeAllow: [
            'constructor',
            'state-variable-immutable' 
          ],
        
          constructorArgs: [
            tellerV2ProxyAddress,
            marketRegistryProxyAddress,
            uniswapFactoryAddress
            
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
deployFn.id = 'lender-commitment-forwarder:alpha:upgrade'
deployFn.tags = [
  'proposal',
  'upgrade',
  'lender-commitment-forwarder:alpha',
  'lender-commitment-forwarder:alpha:upgrade'
]
deployFn.dependencies = ['lender-commitment-forwarder:alpha:deploy']
deployFn.skip = async (hre) => {
 
  return (
    !hre.network.live ||
    ![
      'localhost',
     
      'sepolia' ,
      'polygon' 
      
    ].includes(hre.network.name)
  )
}
export default deployFn