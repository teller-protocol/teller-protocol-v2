// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
 
import "./tokens/TestERC20Token.sol";
 
import "forge-std/console.sol";
  
import { Testable } from "./Testable.sol";
import { LenderCommitmentForwarder } from "../contracts/LenderCommitmentForwarder.sol";

 
import { User } from "./Test_Helpers.sol";
 
import "../contracts/allowlist/EnumerableSetAllowlist.sol";
import "../contracts/mock/LenderCommitmentForwarderMock.sol";

contract EnumerableSetAllowlist_Test is Testable, EnumerableSetAllowlist {
 

    address[] emptyArray;
    address[] borrowersArray;

    
    AllowlistUser private lender;
    AllowlistUser private borrower;

    bool addToAllowlistCalled; 

    LenderCommitmentForwarderMock lenderCommitmentForwarderMock;
    

    constructor()
    EnumerableSetAllowlist(address( new LenderCommitmentForwarderMock() ))
    {}

    function setUp() public {  
      borrower = new AllowlistUser(address(this));  
      lender = new AllowlistUser(address(this));  

 
      borrowersArray = new address[](1);
      borrowersArray[0] = address(borrower);

      LenderCommitmentForwarderMock( commitmentManager ).setLender(address(lender));

        
      addToAllowlistCalled =  false;
    }
 
    function test_setAllowlist() public {


        bool isAllowedBefore = addressIsAllowed(0,address(borrower));

        assertEq(
            isAllowedBefore,
            false,
            "Expected borrower to be disallowed"
        ); 

      LenderCommitmentForwarderMock( commitmentManager ).setLender(address(lender));
 
      
        AllowlistUser(lender).call_setAllowList(
            0,
            borrowersArray
        );

        address[] memory allowedBorrowers = super.getAllowedAddresses(0);
          

        bool isAllowedAfter = addressIsAllowed(0,address(borrower));

        assertEq(
            isAllowedAfter,
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

    function call_setAllowList(
        uint256 commitmentId,
        address[] memory borrowersArray
    ) public { 
         
       EnumerableSetAllowlist(allowlistManager).setAllowlist(  0, borrowersArray );

    }
       

}