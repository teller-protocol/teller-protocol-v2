// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/ILenderCommitmentForwarder.sol";
import "./LenderCommitmentForwarder_G2.sol";

contract LenderCommitmentForwarder is ILenderCommitmentForwarder, LenderCommitmentForwarder_G2 {
    constructor(address _tellerV2, address _marketRegistry)
        LenderCommitmentForwarder_G2(_tellerV2, _marketRegistry)
    {}
}
