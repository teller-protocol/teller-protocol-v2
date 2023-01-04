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
  goerli: {
    marketOwnerAddress: '0xB11ca87E32075817C82Cc471994943a4290f4a14',
    deployerAddress: '0x04cd8462cffe5eddfb923fce634e13bfbdc83886',
    proxyAdminAddress: '0xD27FD721635de713dA155260F4Ca69b717B76Ef9',
    bnplContractAddress: '0x5F96A3cc1b95a3F521f2CB89d20F06D2F48c2477',

    tellerV2Address: '0x1D0eBC060f2897dAc14E482De600cea7896c0A3E',
    marketRegistry: '0x1815f01083afd110373e952b6488f33b048f096b',
    wyvernExchangeAddress: '0x00000000006c3852cbEf3e08E8dF289169EdE581',
    wethAaddress: '0xffc94fb06b924e6dba5f0325bbed941807a018cd',
    marketId: 2,
    craSignerPublicAddress: '0x73F9922Fe625E14ad862E8D2095CE48C1c39A021',
    cryptopunksMarketAddress: '0x0938a5F48B8f33eea3e4Db4320d73e0e795b1c90',
  },
}

const config = FORKING_NETWORK ? contractConfig[FORKING_NETWORK] : {}

export const upgradeFn: DeployFunction = async (hre) => {
  await hre.evm.impersonate(config.deployerAddress)
  const signer = ethers.provider.getSigner(config.deployerAddress)

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

  const seaportEscrowBuyer = await deploy({
    contract: 'SeaportEscrowBuyer',
    args: [config.wyvernExchangeAddress],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
    },
    hre,
  })

  const punksEscrowBuyer = await deploy({
    contract: 'CryptopunksEscrowBuyer',
    args: [config.cryptopunksMarketAddress],
    proxy: {
      proxyContract: 'OpenZeppelinTransparentProxy',
    },
    hre,
  })

  //deploy the implementation

  const upgrade = await upgradeProxyAdminWithImplementation({
    contract: 'BNPLMarket',
    existingProxyAddress: config.bnplContractAddress,
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
