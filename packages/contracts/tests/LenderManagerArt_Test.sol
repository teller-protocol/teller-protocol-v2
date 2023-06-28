// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
  


import "lib/forge-std/src/console.sol";

import { Testable } from "./Testable.sol";
import { LenderManagerArt } from "../contracts/libraries/LenderManagerArt.sol";
 
  

contract LenderManagerArt_Test is Testable {
   

    constructor() {}

    function setUp() public {
       
    }

    function test_generateSVG() public {
        string memory svg = LenderManagerArt.generateSVG(
            22,
            82330000000000420055000,
            address(0),
            20000,
            address(0),
            300,
            55000
        );


        console.log("the svg:");
        console.log(svg);

    }




}