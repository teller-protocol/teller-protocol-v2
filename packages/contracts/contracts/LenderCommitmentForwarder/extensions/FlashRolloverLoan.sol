// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../interfaces/IFlashRolloverLoan.sol";
import "./FlashRolloverLoan_G2.sol";

contract FlashRolloverLoan is IFlashRolloverLoan, FlashRolloverLoan_G2 {
    constructor(    address _tellerV2,
        address _lenderCommitmentForwarder,
        address _poolAddressesProvider)
        FlashRolloverLoan_G2(_tellerV2, _lenderCommitmentForwarder,_poolAddressesProvider)
    {}
}
