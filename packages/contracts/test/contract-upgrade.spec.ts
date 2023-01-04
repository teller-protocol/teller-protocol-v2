/*
Fork the goerli network 
Deploy escrow buyers 

deploy the implementation for new BNPL and use proxy to update 


 FORKING_NETWORK=goerli yarn contracts test  --only-ts


*/

import chai, { expect } from 'chai'
import chaiAsPromised from 'chai-as-promised' 
import { BigNumber, Contract, ContractFactory, Signer, Wallet } from 'ethers'
import hre, { ethers, getNamedSigner, network } from 'hardhat'
import { DeployFunction } from 'hardhat-deploy/dist/types'
import { deploy } from 'helpers/deploy-helpers'
import { upgradeTellerV2Proxy } from './helpers/upgrade-utils'
 
/*

FORKING_NETWORK=mainnet yarn contracts test 


*/
 
const TellerV2Interface =
  require('../generated/artifacts/contracts/TellerV2.sol/TellerV2.json').abi

//const requiredForkingNetworkName = "mainnet"

//this must match what the latest build of solidity
const LATEST_CODE_VERSION = '7'

const validForkingNetworkNames = ['mainnet', 'goerli']

const FORKING_NETWORK = process.env.FORKING_NETWORK

const forkingNetworkIsValid =
  FORKING_NETWORK && validForkingNetworkNames.includes(FORKING_NETWORK)

const contractConfig: any = {
  mainnet: {
    deployerAddress: '0xafe87013dc96ede1e116a288d80fcaa0effe5fe5',
    proxyAdminAddress: '0xcCfFa4e4cBE27D92f926E7B2e396a772Ddf0F2B2',
    tellerV2Address: '0x00182FdB0B880eE24D428e3Cc39383717677C37e',
    marketRegistry: '0x5e30357d5136bc4bfadba1ab341d0da09fe7a9f1',
    wethAddress: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
  },
 
  goerli: {   
    deployerAddress: '0x04cd8462cffe5eddfb923fce634e13bfbdc83886',
    proxyAdminAddress: '0xD27FD721635de713dA155260F4Ca69b717B76Ef9',
    tellerV2Address: '0x1D0eBC060f2897dAc14E482De600cea7896c0A3E',
    marketRegistry: '0x1815f01083afd110373e952b6488f33b048f096b',
    wethAddress: '0xffc94fb06b924e6dba5f0325bbed941807a018cd',
  },
}

const config = FORKING_NETWORK ? contractConfig[FORKING_NETWORK] : {}

describe.only('Contract Upgrade', () => {
  let signer: Signer

 // let marketOwner: Signer

  let tellerV2Contract: Contract
 

  before(async () => {
    if (forkingNetworkIsValid) {
      signer = await getNamedSigner('deployer')

     // await hre.evm.impersonate(config.marketOwnerAddress)
     // marketOwner = ethers.provider.getSigner(config.marketOwnerAddress)

      //we use the proxy address and the upgraded implmentation which should be applied now
      tellerV2Contract = new Contract(
        config.tellerV2Address,
        TellerV2Interface,
        signer
      )

      await upgradeTellerV2Proxy(hre)

     /* const upgradeVersion = await tellerV2Contract.CURRENT_CODE_VERSION()

      if (upgradeVersion != LATEST_CODE_VERSION) {

        //upgrade the contract ! 
        await upgradeTellerV2Proxy(hre)
      }*/
    }
  })

  describe('can upgrade contracts ', () => {
    if (forkingNetworkIsValid) {
      it('should use hardhat network ', async () => {
        hre.network.name.should.eql('hardhat')
      })

      it.skip('should have initialized upgraded ', async () => {
        console.log(tellerV2Contract.CURRENT_CODE_VERSION)
        const upgradeVersion = await tellerV2Contract.CURRENT_CODE_VERSION()
        expect(upgradeVersion).to.eql('7')

         
      })

      it('should submit and accept bid ', async () => {
        console.log(tellerV2Contract)

        


        const submitBid = await tellerV2Contract.submitBid(
            lendingTokenAddress,
            marketplaceId,
            principal,
            duration,
            interestRate,
            metadataURI,
            receiver
        )

        const acceptBid = await tellerV2Contract.lenderAcceptBid(
            bidId
        )
       

         
      })

     /* it.skip('should migrate ERC721 NFT  ', async () => {
        const { tokenAddress, tokenId, tokenType, tokenAmount } = {
          tokenAddress: '0x305305c40d3de1c32f4c3d356abc72bcc6dcf9dc',
          tokenId: '12',
          tokenType: 0,
          tokenAmount: 1,
        }

        const nftContract = new Contract(tokenAddress, ERC721Interface, signer)

        const seaportEscrowLookup =
          await bnplMarketContract.seaportEscrowBuyer()

        console.log({ seaportEscrowLookup })

        expect(seaportEscrowLookup).to.eql(seaportEscrowBuyerContract.address)

        const migrate = await bnplMarketContract
          .connect(marketOwner)
          .transferLegacyAssetToEscrow(
            tokenAddress,
            tokenId,
            tokenType,
            tokenAmount
          )
        await migrate.wait()

        const getOwner = await nftContract.ownerOf(tokenId)

        console.log({ getOwner })

        expect(getOwner).to.eql(seaportEscrowBuyerContract.address)

        const hasAsset = await seaportEscrowBuyerContract.hasOwnershipOfAsset(
          tokenAddress,
          tokenId,

          tokenAmount, //THESE ARE FLIPPED
          tokenType
        )

        console.log({ migrate })
        console.log(hasAsset)

        expect(hasAsset).to.eql(true)

        const migrate2 = await bnplMarketContract
          .connect(marketOwner)
          .transferLegacyAssetToEscrow(
            '0x3af8ccd154490b61d6a3ca06599517086fd746e1',
            '0',
            '1',
            '1'
          )
        await migrate2.wait()

        const hasAsset2 = await seaportEscrowBuyerContract.hasOwnershipOfAsset(
          '0x3af8ccd154490b61d6a3ca06599517086fd746e1',
          '0',

          '1', //THESE ARE FLIPPED
          '1'
        )
        expect(hasAsset2).to.eql(true)
      })*/
    } else {
      it('should not run contract upgrade tests ', async () => {
        hre.network.name.should.eql('hardhat')
      })
    }
  })
})
