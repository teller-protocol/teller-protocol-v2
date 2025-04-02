// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
 
import "./BorrowSwap_G2.sol";

contract BorrowSwap is BorrowSwap_G2 {
    constructor(
        address _tellerV2, 
        address _factory,
        address _swapRouter,
        address _WETH9
    )
        BorrowSwap_G2(
            _tellerV2,
            _factory,
            _swapRouter,
            _WETH9
        )
    {}
}
