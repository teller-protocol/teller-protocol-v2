import chai, { expect } from 'chai'
import { solidity } from 'ethereum-waffle'
import { Signer } from 'ethers'
import hre, { deployments } from 'hardhat'
import moment from 'moment'
import { LenderManager, MarketRegistry, TellerV2} from 'types/typechain'

import { acceptedBid } from './helpers/fixtures/acceptedBid'

chai.should()
chai.use(solidity)

const { getNamedSigner } = hre

// eslint-disable-next-line @typescript-eslint/no-empty-interface
interface SetupOptions {}

interface SetupReturn {
  lenderManager: LenderManager
  marketRegistry: MarketRegistry
  tellerV2: TellerV2
}

const setup = deployments.createFixture<SetupReturn, SetupOptions>(
  async (hre, _opts) => {
    await hre.deployments.fixture(['teller-v2'], {
      keepExistingDeployments: false,
    })

    const lenderManager = await hre.contracts.get<LenderManager>(
      'LenderManager'
    )

    const marketRegistry = await hre.contracts.get<MarketRegistry>(
      'MarketRegistry'
    )

    const tellerV2 = await hre.contracts.get<TellerV2>('TellerV2')

    return {
      lenderManager,
      marketRegistry,
      tellerV2,
    }
  }
)

describe('LenderManager', () => {
  let lenderManager: LenderManager
  let lender: Signer
  let borrower: Signer
  let newLender: Signer
  let newLenderAddress: string

  before(async () => {
    const result = await setup()
    lenderManager = result.lenderManager

    lender = await getNamedSigner('lender')
    borrower = await getNamedSigner('borrower')
    newLender = await getNamedSigner('lender2')
    newLenderAddress = await newLender.getAddress()

    const marketRegistry = result.marketRegistry

    const marketOwner = await getNamedSigner('marketowner')

    const paymentCycleDuration = moment.duration(30, 'days').asSeconds()
    const paymentDefaultDuration = moment.duration(180, 'days').asSeconds()
    const loanExpirationTime = moment.duration(1, 'days').asSeconds()

    await marketRegistry
      .connect(marketOwner)
      [
        'createMarket(address,uint32,uint32,uint32,uint16,bool,bool,uint8,string)'
      ](
        await marketOwner.getAddress(),
        paymentCycleDuration,
        paymentDefaultDuration,
        loanExpirationTime,
        0,
        true,
        false,
        '0',
        'uri://'
      )
  })

  describe('getActiveLoanLender', () => {
    it('should return the active lender for a loan from the Lender Manager', async () => {
      const { bidId } = await acceptedBid({ borrower, lender })

      const activeLender = await lenderManager.callStatic.getActiveLoanLender(
        bidId
      )

      expect(await lender.getAddress()).to.eql(activeLender)
    })
  })

  describe('setNewLender', () => {
    it('should be able to set a new active loan lender', async () => {
      const { bidId, tellerV2 } = await acceptedBid({ borrower, lender })
      const bidData = await tellerV2.bids(bidId)

      await lenderManager
        .connect(lender)
        .setNewLender(bidId, newLenderAddress, bidData.marketplaceId)
        .should.emit(lenderManager, 'NewLenderSet')
        .withArgs(newLenderAddress, bidId)

      const activeLender = await lenderManager.callStatic.getActiveLoanLender(
        bidId
      )

      expect(activeLender).to.eql(newLenderAddress)
    })
    it('should not be able to set new active loan lender as not the loan owner', async () => {
      const { bidId, tellerV2 } = await acceptedBid({ borrower, lender })
      const bidData = await tellerV2.bids(bidId)

      await lenderManager
        .connect(borrower)
        .setNewLender(bidId, newLenderAddress, bidData.marketplaceId)
        .should.be.revertedWith('Not loan owner')
    })
  })
})
