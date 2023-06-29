// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
  
import {CollateralType,Collateral} from "../contracts/interfaces/escrow/ICollateralEscrowV1.sol";


import "lib/forge-std/src/console.sol";

import { Testable } from "./Testable.sol";
import { LenderManagerArt } from "../contracts/libraries/LenderManagerArt.sol";
 
  
import "../contracts/mock/WethMock.sol";

contract LenderManagerArt_Test is Testable {
   
   WethMock wethMock;

    constructor() {}

    function setUp() public {
       
       wethMock = new WethMock();

    }

    function test_generateSVG() public {

 

        Collateral memory _collateral = Collateral({
            _collateralType: CollateralType.ERC20,
            _collateralAddress: address(wethMock),
            _amount: 20000,
            _tokenId : 0 
        });

        string memory svg = LenderManagerArt.generateSVG(
            22,
            82330000000000420055000,
            address(wethMock),
          //  20000,
          //  address(0),
            _collateral,
            300,
            55000
        );


        console.log("the svg:");
        console.log(svg);

    }




}