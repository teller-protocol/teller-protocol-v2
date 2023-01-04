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
import { upgradeFn } from './helpers/upgrade-utils'
 


const ERC721Interface = require('../contracts/abi/ERC721.json')
const BNPLMarketInterface =
  require('../generated/artifacts/contracts/BNPLMarket.sol/BNPLMarket.json').abi
const SeaportEscrowBuyerInterface =
  require('../generated/artifacts/contracts/SeaportEscrowBuyer.sol/SeaportEscrowBuyer.json').abi

//const requiredForkingNetworkName = "mainnet"

//this must match what the latest build of solidity
const LATEST_CODE_VERSION = '3.2'

const validForkingNetworkNames = ['mainnet', 'goerli']

const FORKING_NETWORK = process.env.FORKING_NETWORK

const forkingNetworkIsValid =
  FORKING_NETWORK && validForkingNetworkNames.includes(FORKING_NETWORK)

const contractConfig: any = {
  mainnet: {
    deployerAddress: '0xafe87013dc96ede1e116a288d80fcaa0effe5fe5',
    proxyAdminAddress: '0xcCfFa4e4cBE27D92f926E7B2e396a772Ddf0F2B2',
    bnplContractAddress: '0x260C32eB38D1403bd51B83B5b7047812C70B7845',
    tellerV2Address: '0x00182FdB0B880eE24D428e3Cc39383717677C37e',
    marketRegistry: '0x5e30357d5136bc4bfadba1ab341d0da09fe7a9f1',
    wyvernExchangeAddress: '0x00000000006c3852cbEf3e08E8dF289169EdE581',
    wethAaddress: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
    marketId: 1,
    craSignerPublicAddress: '0x73F9922Fe625E14ad862E8D2095CE48C1c39A021',
    cryptopunksMarketAddress: '0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB',
  },
  rinkeby: {
    marketOwnerAddress: '0xB11ca87E32075817C82Cc471994943a4290f4a14',

    bnplContractAddress: '',
    tellerV2Address: '0x21d3D541937de52ac5e4aF6254d0d2134d9B7c9e',
    marketRegistry: '',
    wyvernExchangeAddress: '0x00000000006c3852cbEf3e08E8dF289169EdE581',
    wethAaddress: '0x0bb7509324ce409f7bbc4b701f932eaca9736ab7',
    marketId: 3,
    craSignerPublicAddress: '0x73F9922Fe625E14ad862E8D2095CE48C1c39A021',
    cryptopunksMarketAddress: '0xcc495748df37dcfb0c1041a6fdfa257d350afd60',
  },
  goerli: {
    marketOwnerAddress: '0xB11ca87E32075817C82Cc471994943a4290f4a14',
    deployerAddress: '0x04cd8462cffe5eddfb923fce634e13bfbdc83886',
    proxyAdminAddress: '0xD27FD721635de713dA155260F4Ca69b717B76Ef9',
    bnplContractAddress: '0x5F96A3cc1b95a3F521f2CB89d20F06D2F48c2477',

    marketId: 2,

    tellerV2Address: '0x1D0eBC060f2897dAc14E482De600cea7896c0A3E',
    marketRegistry: '0x1815f01083afd110373e952b6488f33b048f096b',
    wyvernExchangeAddress: '0x00000000006c3852cbEf3e08E8dF289169EdE581',
    wethAaddress: '0xffc94fb06b924e6dba5f0325bbed941807a018cd',

    craSignerPublicAddress: '0x73F9922Fe625E14ad862E8D2095CE48C1c39A021',
    cryptopunksMarketAddress: '0x0938a5F48B8f33eea3e4Db4320d73e0e795b1c90',
  },
}

const config = FORKING_NETWORK ? contractConfig[FORKING_NETWORK] : {}

describe('Contract Upgrade', () => {
  let signer: Signer

  let marketOwner: Signer

  let bnplMarketContract: Contract

  let seaportEscrowBuyerContract: Contract

  before(async () => {
    if (forkingNetworkIsValid) {
      signer = await getNamedSigner('deployer')

      await hre.evm.impersonate(config.marketOwnerAddress)
      marketOwner = ethers.provider.getSigner(config.marketOwnerAddress)

      //we use the proxy address and the upgraded implmentation which should be applied now
      bnplMarketContract = new Contract(
        config.bnplContractAddress,
        BNPLMarketInterface,
        signer
      )

      const upgradeVersion = await bnplMarketContract.upgradedToVersion()

      if (upgradeVersion != LATEST_CODE_VERSION) {
        await upgradeFn(hre)
      }
    }
  })

  describe('can upgrade contracts ', () => {
    if (forkingNetworkIsValid) {
      it('should use hardhat network ', async () => {
        hre.network.name.should.eql('hardhat')
      })

      it('should have initialized seaport escrow buyer ', async () => {
        const upgradeVersion = await bnplMarketContract.upgradedToVersion()
        expect(upgradeVersion).to.eql('3.2')

        const seaportEscrowBuyer = await bnplMarketContract.seaportEscrowBuyer()
        expect(seaportEscrowBuyer).to.not.eql(ethers.constants.AddressZero) //why is this zero when we fork ?
      })

      it.skip('should migrate ERC721 NFT  ', async () => {
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
      })
    } else {
      it('should not run contract upgrade tests ', async () => {
        hre.network.name.should.eql('hardhat')
      })
    }
  })
})
