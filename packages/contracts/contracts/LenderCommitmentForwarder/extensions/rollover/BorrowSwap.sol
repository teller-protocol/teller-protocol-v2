// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./BorrowSwap_G4.sol";

contract BorrowSwap is BorrowSwap_G4 {
    constructor(
        address _tellerV2,
        address _swapAdapter
    )
        BorrowSwap_G4(
            _tellerV2,
            _swapAdapter
        )
    {}
}
