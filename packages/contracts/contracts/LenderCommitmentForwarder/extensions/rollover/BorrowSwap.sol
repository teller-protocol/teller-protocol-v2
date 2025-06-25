// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
 
import "./BorrowSwap_G3.sol";

contract BorrowSwap is BorrowSwap_G3 {
    constructor(
        address _tellerV2,         
        address _swapRouter,
        address _quoter
    )
        BorrowSwap_G3(
            _tellerV2,         
            _swapRouter,
            _quoter 
        )
    {}
}
