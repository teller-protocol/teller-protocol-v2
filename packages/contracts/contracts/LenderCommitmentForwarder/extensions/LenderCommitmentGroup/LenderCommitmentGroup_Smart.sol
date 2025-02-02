// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {LenderCommitmentGroup_Smart_R2} from "./LenderCommitmentGroup_Smart_R2.sol";

contract LenderCommitmentGroup_Smart is LenderCommitmentGroup_Smart_R2 {

 


    constructor(
        address _tellerV2,
        address _smartCommitmentForwarder,
        address _uniswapV3Factory
    ) LenderCommitmentGroup_Smart_R2(_tellerV2, _smartCommitmentForwarder, _uniswapV3Factory ) {
       //disable initializer? 
    }



}
