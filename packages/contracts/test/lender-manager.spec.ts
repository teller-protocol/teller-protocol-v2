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

describe.only('LenderManager', () => {
  let lenderManager: LenderManager
  let lender: Signer
  let borrower: Signer

  before(async () => {
    const result = await setup()
    lenderManager = result.lenderManager

    lender = await getNamedSigner('lender')
    borrower = await getNamedSigner('borrower')

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
        false,
        false,
        '0',
        'uri://'
      )
  })

  describe('getActiveLoanLender', () => {
    it('should return the active lender for a loan from the Lender Manager', async () => {
      const { tellerV2, bidId } = await acceptedBid({ borrower, lender })

      const bidData = await tellerV2.bids(bidId)

      const activeLender = await lenderManager.callStatic.getActiveLoanLender(
        bidId
      )

      expect(bidData.lender).to.eql(activeLender)
    })
  })
})
