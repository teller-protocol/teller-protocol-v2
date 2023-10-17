// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../interfaces/IFlashRolloverLoan.sol";
import "./FlashRolloverLoan_G3.sol";

contract FlashRolloverLoan is IFlashRolloverLoan, FlashRolloverLoan_G3 {
    constructor(
        address _tellerV2,
        address _lenderCommitmentForwarder,
        address _poolAddressesProvider
    )
        FlashRolloverLoan_G3(
            _tellerV2,
            _lenderCommitmentForwarder,
            _poolAddressesProvider
        )
    {}
}
