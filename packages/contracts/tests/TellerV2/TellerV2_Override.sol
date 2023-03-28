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

    function setLenderManagerSuper(address lenderManager) public initializer {
        _setLenderManager(lenderManager);
    }
}
