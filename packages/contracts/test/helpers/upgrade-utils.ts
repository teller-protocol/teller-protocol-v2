import { getTokens } from 'config'
import { BigNumber, Contract, ContractFactory, Signer, Wallet } from 'ethers'
import hre, { ethers, getNamedSigner, network } from 'hardhat'
import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'
import {
  upgradeProxyAdminWithImplementation,
  upgradeProxyWithImplementation,
} from './proxy-upgrade-utils'

const FORKING_NETWORK = process.env.FORKING_NETWORK
 
const contractConfig: any = {
  mainnet: {
    deployerAddress: '0xafe87013dc96ede1e116a288d80fcaa0effe5fe5',
    proxyAdminAddress: '0xcCfFa4e4cBE27D92f926E7B2e396a772Ddf0F2B2',
    tellerV2Address: '0x00182FdB0B880eE24D428e3Cc39383717677C37e',
    marketRegistry: '0x5e30357d5136bc4bfadba1ab341d0da09fe7a9f1',
    wethAaddress: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
  },
 
  goerli: {   
    deployerAddress: '0x04cd8462cffe5eddfb923fce634e13bfbdc83886',
    proxyAdminAddress: '0xD27FD721635de713dA155260F4Ca69b717B76Ef9',
    tellerV2Address: '0x1D0eBC060f2897dAc14E482De600cea7896c0A3E',
    marketRegistry: '0x1815f01083afd110373e952b6488f33b048f096b',
    wethAaddress: '0xffc94fb06b924e6dba5f0325bbed941807a018cd',
  },
}

const config = FORKING_NETWORK ? contractConfig[FORKING_NETWORK] : {}

export const upgradeTellerV2Proxy: DeployFunction = async (hre) => {
  await hre.evm.impersonate(config.deployerAddress)
  const signer = ethers.provider.getSigner(config.deployerAddress)

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
  })
  */

   

  //deploy the implementation

  const upgrade = await upgradeProxyAdminWithImplementation({
    contract: 'TellerV2',
    existingProxyAddress: config.tellerV2Address,
    proxyAdminAddress: config.proxyAdminAddress,
    signer,
    args: [
      config.tellerV2Address,
      config.marketRegistry,
      config.marketId,
      config.wethAaddress,
      trustedForwarder.address,
      config.craSignerPublicAddress,
    ],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
      execute: {
        init: {
          methodName: 'initialize',
          args: [
            config.cryptopunksMarketAddress,
            seaportEscrowBuyer.address,
            punksEscrowBuyer.address,
          ],
        },
        onUpgrade: {
          methodName: 'onUpgrade',
          args: [],
        },
      },
    },
  })
}
