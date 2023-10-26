// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/ILenderCommitmentForwarder.sol";
import "./LenderCommitmentForwarder_G4.sol";

contract LenderCommitmentForwarderStaging is
    ILenderCommitmentForwarder,
    LenderCommitmentForwarder_G4
{
    constructor(address _tellerV2, address _marketRegistry)
        LenderCommitmentForwarder_G4(_tellerV2, _marketRegistry)
    {
        // we only want this on an proxy deployment so it only affects the impl
        _disableInitializers();
    }
}
