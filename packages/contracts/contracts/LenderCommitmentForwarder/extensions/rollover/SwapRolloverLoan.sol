// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./SwapRolloverLoan_G3.sol";

contract SwapRolloverLoan is SwapRolloverLoan_G3 {
    constructor(
        address _tellerV2,
        address _factory,
        address _WETH9
    )
        SwapRolloverLoan_G3(
            _tellerV2,
            _factory,
            _WETH9
        )
    {}
}
