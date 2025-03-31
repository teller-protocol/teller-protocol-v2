import { DeployFunction } from 'hardhat-deploy/dist/types'


const uniswapV3Factory: { [networkName: string]: string } = {
  mainnet: '0x1F98431c8aD98523631AE4a59f267346ea31F984',
  polygon: '0x1F98431c8aD98523631AE4a59f267346ea31F984',
  arbitrum: '0x1F98431c8aD98523631AE4a59f267346ea31F984',
  base: '0x33128a8fC17869897dcE68Ed026d694621f6FDfD',
}

const networksWithUniswap: string[] = Object.keys(uniswapV3Factory)

const deployFn: DeployFunction = async (hre) => {
  const tellerV2 = await hre.contracts.get('TellerV2')
   

  hre.log('Deploying Loan Referral Forwarder V2...')


  const networkName = hre.network.name

  const LoanReferralForwarder = await hre.deployProxy('LoanReferralForwarderV2', {
    unsafeAllow: ['constructor', 'state-variable-immutable'],
    constructorArgs: [
      await tellerV2.getAddress(),
      
      
    ],
  })

  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-forwarder:extensions:loan-referral-forwarder-v2:deploy'
deployFn.tags = [
  'lender-commitment-forwarder',
  'lender-commitment-forwarder:extensions',
  'lender-commitment-forwarder:extensions:deploy',
  'lender-commitment-forwarder:extensions:loan-referral-forwarder',
  'lender-commitment-forwarder:extensions:loan-referral-forwarder-v2:deploy',
]
deployFn.dependencies = [
  'teller-v2:deploy',
  'lender-commitment-forwarder:deploy',
]

deployFn.skip = async (hre) => {
  return true ; 
  //return !hre.network.live || !networksWithUniswap.includes(hre.network.name)
}
export default deployFn
