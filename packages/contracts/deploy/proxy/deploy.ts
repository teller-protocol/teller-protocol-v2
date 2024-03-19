import { AbiCoder } from 'ethers'
import { ethers } from 'hardhat'
import { DeployFunction } from 'hardhat-deploy/dist/types'


/*
This is an example deploy script that deploys a TransparentUpgradeableProxy manually assuming the impl is already deployed
*/
const deployFn: DeployFunction = async (hre) => {

  hre.log('Deploy proxy custom...')

  const tellerV2 = await hre.contracts.get('TellerV2')
  const marketRegistry = await hre.contracts.get('MarketRegistry')

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


  /*
  const lenderCommitmentForwarderAlpha = await hre.deployProxy(
    'LenderCommitmentForwarderAlpha',
    {
      unsafeAllow: ['constructor', 'state-variable-immutable'],
      constructorArgs: [
        await tellerV2.getAddress(),
        await marketRegistry.getAddress(),
        uniswapFactoryAddress
      ]
    }
  )*/

    // Address of the already deployed implementation contract
    const implementationAddress = "0xf7b14778035feaf44540a0bc1d4ed859bcb28229";

    // Your deployer account address or the ProxyAdmin contract's address
    const adminAddress = "0x4d41AA4BdE441A5A4477f307FC1Da20Ee2615F66";
  
    // Prepare the initializer function call
    // If your initializer function is `initialize(arg1, arg2)`, encode it like below:
    /*const initializeData = AbiCoder.defaultAbiCoder().encode(
      ["address", "address", "address"], // Update these types according to your initializer function
      [await tellerV2.getAddress(), await marketRegistry.getAddress(), uniswapFactoryAddress] // Update these values with your initializer parameters
    );
*/

    const initializeData = '0x';

  
    // Deploy the TransparentUpgradeableProxy contract
    const TransparentUpgradeableProxy = await ethers.getContractFactory("TransparentUpgradeableProxy");
    const proxy = await TransparentUpgradeableProxy.deploy(implementationAddress, adminAddress, initializeData);
  
  
    console.log("Proxy deployed to:", await proxy.getAddress());



  return true
}

// tags and deployment
deployFn.id = 'lender-commitment-forwarder:proxy:deploy'
deployFn.tags = [
  'lender-commitment-forwarder', 
  'lender-commitment-forwarder:proxy:deploy'
]

deployFn.skip = async (hre) => {
  return !(
    hre.network.live &&
    [  'localhost'].includes(
      hre.network.name
    )
  )
}
deployFn.dependencies = ['teller-v2:deploy', 'market-registry:deploy']
export default deployFn