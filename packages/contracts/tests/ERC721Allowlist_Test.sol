// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
 
import "forge-std/console.sol";
  
import { Testable } from "./Testable.sol";
import { LenderCommitmentForwarder } from "../contracts/LenderCommitmentForwarder.sol";


import "./tokens/TestERC721Token.sol";
 
import { User } from "./Test_Helpers.sol";
 
import "../contracts/allowlist/ERC721Allowlist.sol";

contract EnumerableSetAllowlist_Test is Testable, ERC721Allowlist {
  

    
    AllowlistUser private lender;
    AllowlistUser private borrower;
 

    constructor()
    ERC721Allowlist(address(new AllowlistUser(address(this))) ,address(new TestERC721Token("TEST","TST"))  )
    {}

    function setUp() public {
        
      borrower = new AllowlistUser(address(this));

   
    }
 
    function test_addressIsAllowed() public {

        bool allowedBefore = super.addressIsAllowed(0,address(borrower));

        assertEq(
            allowedBefore,
            false,
            "Expected borrower to be disallowed"
        );

        uint256 tokenId = TestERC721Token(address(accessToken)).mint(address(borrower));
     

        bool allowedAfter = super.addressIsAllowed(0,address(borrower));

        assertEq(
            allowedAfter,
            true,
            "Expected borrower to be allowed"
        );
    }
 

}


contract AllowlistUser {

    address allowlistManager;

    constructor( address _allowlistManager ){
        allowlistManager = _allowlistManager; 
    }

 
       

}