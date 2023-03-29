// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TellerV2, Bid, BidState, Collateral, Payment, LoanDetails, Terms } from "../../contracts/TellerV2.sol";

 

contract TellerV2_Override is TellerV2 {
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

}
