// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
  
import {CollateralType,Collateral} from "../contracts/interfaces/escrow/ICollateralEscrowV1.sol";


import "lib/forge-std/src/console.sol";

import { Testable } from "./Testable.sol";
import { LenderManagerArt } from "../contracts/libraries/LenderManagerArt.sol";
 
import "./tokens/TestERC1155Token.sol";
import "./tokens/TestERC721Token.sol";
import "../contracts/mock/WethMock.sol";

contract LenderManagerArt_Test is Testable {
   
   WethMock wethMock;
   TestERC721Token erc721Mock;
   TestERC1155Token erc1155Mock;

    constructor() {}

    function setUp() public {
       
       wethMock = new WethMock();
       erc721Mock = new TestERC721Token("BAYC", "BAYC");
       erc1155Mock = new TestERC1155Token("SAND");
    }

    function test_generateSVG() public {

 

        Collateral memory _collateral = Collateral({
            _collateralType: CollateralType.ERC721,
            _collateralAddress: address(erc721Mock),
            _amount: 1,
            _tokenId : 150 
        });

        string memory svg = LenderManagerArt.generateSVG(
            22,
            82330000000000420055000,
            address(wethMock), 
            _collateral,
            300,
            550000
        );


        console.log("the svg:");
        console.log(svg);

    }


    //add more unit tests here 
    function test_get_token_decimals() public {


        uint256 decimals = LenderManagerArt._get_token_decimals(address(wethMock));
 

        assertEq(decimals, 18);


    }

    function test_get_token_decimals_erc721() public {

        uint256 decimals = LenderManagerArt._get_token_decimals(address(erc721Mock));
 

        assertEq(decimals, 0);

    }

    function test_get_interest_rate_formatted() public {

        string memory interestRate = LenderManagerArt._get_interest_rate_formatted(30000);
 
        assertEq(interestRate, "300 %");

    }

    function test_get_duration_formatted() public {

        string memory duration = LenderManagerArt._get_duration_formatted(30000);
 
        assertEq(duration, "8 hours");


    }

    function test_get_duration_formatted_2() public {

        string memory duration = LenderManagerArt._get_duration_formatted(3000000);
 
        assertEq(duration, "4 weeks");


    }


    function test_get_token_symbol() public {
        string memory symbol = LenderManagerArt._get_token_symbol(address(wethMock),"fallback");
 
        assertEq(symbol, "WETH");
    }

    function test_get_token_symbol_fallback() public {
        string memory symbol = LenderManagerArt._get_token_symbol(address(0),"fallback");
 
        assertEq(symbol, "fallback");
    }

    function test_get_collateral_label() public {


        Collateral memory _collateral = Collateral({
            _collateralType: CollateralType.ERC721,
            _collateralAddress: address(erc721Mock),
            _amount: 1,
            _tokenId : 150 
        });

        string memory label = LenderManagerArt._get_collateral_label(_collateral);
 
        assertEq(label, "BAYC");

    }


}