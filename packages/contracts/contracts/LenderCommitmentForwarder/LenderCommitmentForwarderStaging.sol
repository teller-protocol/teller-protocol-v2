// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

 
import "./LenderCommitmentForwarder_G3.sol";

contract LenderCommitmentForwarderStaging is
    
    LenderCommitmentForwarder_G3
{
    constructor(address _tellerV2, address _marketRegistry,  address _uniswapV3Factory)
        LenderCommitmentForwarder_G3(_tellerV2, _marketRegistry, _uniswapV3Factory)
    {
        // we only want this on an proxy deployment so it only affects the impl
        _disableInitializers();
    }
}
