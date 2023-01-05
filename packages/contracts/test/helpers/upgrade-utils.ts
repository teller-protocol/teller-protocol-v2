import { getTokens } from 'config'
import { BigNumber, Contract, ContractFactory, Signer, Wallet } from 'ethers'
import hre, { ethers, upgrades, getNamedSigner, network } from 'hardhat'
import { DeployFunction } from 'hardhat-deploy/dist/types'
 
import { deploy } from 'helpers/deploy-helpers'
import { isInitialized } from 'helpers/oz-contract-helpers'
import { impersonate } from './impersonate'
import {
  upgradeProxyAdminWithImplementation,
  upgradeProxyWithImplementation,
} from './proxy-upgrade-utils'

const HARDHAT_DEPLOY_FORK = process.env.HARDHAT_DEPLOY_FORK
 
const contractConfig: any = {
  mainnet: {
    deployerAddress: '0xAFe87013dc96edE1E116a288D80FcaA0eFFE5fe5',
    proxyAdminAddress: '0xcCfFa4e4cBE27D92f926E7B2e396a772Ddf0F2B2',
    tellerV2Address: '0x00182FdB0B880eE24D428e3Cc39383717677C37e',
    marketRegistryAddress: '0x5e30357d5136bc4bfadba1ab341d0da09fe7a9f1',
    wethAddress: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
    reputationManagerAddress: '0xF0da18a5b53a6C0c4e763013A8DAEeD895A93627',
    lenderCommitmentForwarderAddress: '0x17A8e82351661DFD568FEE6D7c38695b67e1e924'
  },
 
  goerli: {   
    deployerAddress: '0x04cd8462cffe5eddfb923fce634e13bfbdc83886',
    proxyAdminAddress: '0xD27FD721635de713dA155260F4Ca69b717B76Ef9',
    tellerV2Address: '0x1D0eBC060f2897dAc14E482De600cea7896c0A3E',
    marketRegistryAddress: '0x1815f01083afd110373e952b6488f33b048f096b',
    wethAddress: '0xffc94fb06b924e6dba5f0325bbed941807a018cd',
    reputationManagerAddress: '0xF4d6441D421d1dcFB2d6B3E4490C9161b4529920',
    lenderCommitmentForwarderAddress: '0xC2418B857F9147AF5eB4517B23e9a966b368328f'
  },
}

const config = HARDHAT_DEPLOY_FORK ? contractConfig[HARDHAT_DEPLOY_FORK] : {}


export const upgradeTellerV2Proxy: DeployFunction = async (hre) => {
 // await hre.evm.impersonate(config.deployerAddress)
 
 
 await impersonate( config.deployerAddress, ethers.provider)
 
 const signer = ethers.provider.getSigner(config.deployerAddress)

  const protocolFee = 5 // 0.05%

  const tokens = await getTokens(hre)
  const lendingTokens = [tokens.all.DAI, tokens.all.USDC, tokens.all.WETH]
  if ('USDCT' in tokens.all) {
    lendingTokens.push(tokens.all.USDCT)
  }

/*
  const trustedForwarder = await deploy({
    contract: 'MetaForwarder',
    skipIfAlreadyDeployed: false, 
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init: {
          methodName: 'initialize',
          args: [],
        },
      },
    },
    hre,
  }, config.deployerAddress)*/

  let trustedForwarderAddress = "0x1E05c45A674b332e2c7C56e8D945aACF3C825c41"
    
  console.log('deployed meta forwarder')
 
  
    const collateralEscrowV1 = await hre.ethers.getContractFactory(
      'CollateralEscrowV1'
    )

    // Deploy escrow beacon implementation
    const collateralEscrowBeacon = await upgrades.deployBeacon(collateralEscrowV1)
    await collateralEscrowBeacon.deployed()
  
    const collateralManager = await deploy({
      contract: 'CollateralManager',
      args: [],
      proxy: {
        proxyContract: 'OpenZeppelinTransparentProxy',
      },
      hre,
    }, config.deployerAddress)

    const collateralManagerIsInitialized = await isInitialized(
      collateralManager.address
    )
    if (!collateralManagerIsInitialized) {
      await collateralManager.initialize(
        collateralEscrowBeacon.address,
        config.tellerV2Address
      )
    }



  //deploy the implementation

  const upgrade = await upgradeProxyAdminWithImplementation({
    contract: 'TellerV2',
    existingProxyAddress: config.tellerV2Address,
    proxyAdminAddress: config.proxyAdminAddress,
    signer,
    args: [    
      trustedForwarderAddress, 
    ],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init: {
          methodName: 'initialize',
          args: [
            protocolFee,
            config.marketRegistryAddress,
            config.reputationManagerAddress, 
            config.lenderCommitmentForwarderAddress, 
            lendingTokens,
            collateralManager.address   
          ],
        },
        onUpgrade: undefined 
        
        //call onUpgrade method ?
        /*
        {
          methodName: 'onUpgrade',
          args: [],
        }
        */
      },
    },
  })

  return upgrade
}
