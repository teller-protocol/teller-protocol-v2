/*
Fork the goerli network 
Deploy escrow buyers 

deploy the implementation for new BNPL and use proxy to update 


 FORKING_NETWORK=goerli yarn contracts test  --only-ts


*/

import chai, { expect } from 'chai'
import chaiAsPromised from 'chai-as-promised' 
import { BigNumber, Contract, ContractFactory, Signer, Wallet } from 'ethers'
import hre, {ethers, getNamedSigner, network, toBN} from 'hardhat'
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
    usdcAddress: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
  },
 
  goerli: {   
    deployerAddress: '0x04cd8462cffe5eddfb923fce634e13bfbdc83886',
    proxyAdminAddress: '0xD27FD721635de713dA155260F4Ca69b717B76Ef9',
    tellerV2Address: '0x1D0eBC060f2897dAc14E482De600cea7896c0A3E',
    marketRegistry: '0x1815f01083afd110373e952b6488f33b048f096b',
    wethAddress: '0xffc94fb06b924e6dba5f0325bbed941807a018cd',
    usdcAddress: '0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C',
  },
}

const config = FORKING_NETWORK ? contractConfig[FORKING_NETWORK] : {}

describe.only('Contract Upgrade', () => {
  let signer: Signer
  let borrower: Signer

 // let marketOwner: Signer

  let tellerV2Contract: Contract
 

  before(async () => {
    if (forkingNetworkIsValid) {
      signer = ethers.provider.getSigner(config.deployerAddress)//await getNamedSigner('deployer')
      borrower = await getNamedSigner('borrower')

     // await hre.evm.impersonate(config.marketOwnerAddress)
     // marketOwner = ethers.provider.getSigner(config.marketOwnerAddress)

      //we use the proxy address and the upgraded implmentation which should be applied now
      tellerV2Contract = new Contract(
        config.tellerV2Address,
        TellerV2Interface,
        signer
      )

      let upgrade = await upgradeTellerV2Proxy(hre)

      console.log({upgrade})

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

      it('should have bytecode for the contract', async () => {

        let deployedContractBytecode = await ethers.provider.getCode(config.tellerV2Address)
        console.log({deployedContractBytecode})

        expect(deployedContractBytecode).to.not.eql('0x')
      })

      it('should submit and accept bid ', async () => {


     

        const tellerContract = new Contract(config.tellerV2Address, TellerV2Interface, ethers.provider)

        const borrowerAddress = await borrower.getAddress()

        const submittedBid = await tellerV2Contract
          .connect(borrower)
          [
            'submitBid(address,uint256,uint256,uint32,uint16,string,address,(uint8,uint256,uint256,address)[])'
          ](
            config.wethAddress, //lendingTokenAddress,
            1, //marketplaceId,
            toBN(1, 16), // 0.01 principal,
            '31557600', //duration,
            '5000', //interestRate,
            '', //metadataURI,
            borrowerAddress, //receiver
            [
              {
                _collateralType: 0, // ERC20
                _amount: toBN(100, 6), // 0.01
                _tokenId: 0,
                _collateralAddress: config.usdcAddress, // USDC
              },
            ]
          )

        console.log({tellerContract})
        console.log('test 1')
        const bidId = await tellerContract.bidId.call()

        console.log('test 2')
        const acceptBid = await tellerV2Contract
            .connect(signer)
            .lenderAcceptBid(bidId)
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
