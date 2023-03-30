// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TellerV2, Bid, BidState, Collateral, Payment, LoanDetails, Terms } from "../../contracts/TellerV2.sol";

 import "../../contracts/interfaces/IMarketRegistry.sol";
 import "../../contracts/interfaces/IReputationManager.sol";

contract TellerV2_Override is TellerV2 {


    bool public cancelBidWasCalled; 
    bool public repayLoanWasCalled;
    address public mockMsgSenderForMarket;



    constructor()
        TellerV2(address(0))
    {
    }

    function mock_pause(bool _shouldPause) public {
        _shouldPause ? _pause() : _unpause();
    }

    function mock_setBid(uint256 bidId, Bid memory bid) public {
        bids[bidId] = bid;
    }

    function mock_addUriToMapping(uint256 bidId, string memory uri) public {
        uris[bidId] = uri;
    }

    function setLenderManagerSuper(address lenderManager) public initializer {
        _setLenderManager(lenderManager);
    }
    
    function setMarketRegistrySuper(address _marketRegistry) public initializer {
        
        marketRegistry = IMarketRegistry(_marketRegistry);
    }

    function setReputationManagerSuper(address _reputationManager) public initializer {
        reputationManager = IReputationManager(_reputationManager);
    }



    function mock_setBidState(uint256 bidId, BidState state) public {
        bids[bidId].state = state;
    }  

    function mock_setBidDefaultDuration(uint256 bidId, uint32 defaultDuration) public {
        bidDefaultDuration[bidId] = defaultDuration;
    }

    function mock_setBidExpirationTime(uint256 bidId, uint32 expirationTime) public {
        bidExpirationTime[bidId] = expirationTime;
    }


    function mock_initialize(  )  public initializer {

         __ProtocolFee_init( 0 );

        __Pausable_init();

    }

    function setMockMsgSenderForMarket(address _sender) public {
        mockMsgSenderForMarket = _sender;
    }


    function _cancelBidSuper(
        uint256 bidId
    ) public {
        super._cancelBid(bidId);
    }
    
    function _repayLoanSuper( 
         uint256 _bidId,
        Payment memory _payment,
        uint256 _owedAmount,
        bool _shouldWithdrawCollateral)
    public {
        super._repayLoan(_bidId, _payment, _owedAmount, _shouldWithdrawCollateral);
    }



    /*

    Overrides 

    */

    function _msgSenderForMarket(uint256 _marketId)
        internal
        view
        override
        returns (address)
    {
        return mockMsgSenderForMarket;
    }




    function _cancelBid(uint256 _bidId)
    internal 
    override
    {
        cancelBidWasCalled = true;
    }

    function _repayLoan(
        uint256 _bidId,
        Payment memory _payment,
        uint256 _owedAmount,
        bool _shouldWithdrawCollateral
    ) internal override {

        repayLoanWasCalled = true;
    }

}
