// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
 
import "./resolvers/TestERC20Token.sol";
 
import { Testable } from "./Testable.sol";
import { LenderCommitmentForwarder } from "../contracts/LenderCommitmentForwarder.sol";

 
import { User } from "./Test_Helpers.sol";
 
import "../contracts/allowlist/EnumerableSetAllowlist.sol";

contract EnumerableSetAllowlist_Test is Testable, EnumerableSetAllowlist {
 

    address[] emptyArray;
    address[] borrowersArray;

    User private marketOwner;
    User private lender;
    User private borrower;

    bool addToAllowlistCalled; 


    constructor()
    EnumerableSetAllowlist(address(0))
    {}

    function setUp() public {
        
        //allowlistManager = new AllowlistManagerMock();

      borrowersArray = new address[](1);
      borrowersArray[0] = address(borrower);
        
      addToAllowlistCalled =  false;
    }
 
    function test_setAllowlist() public {

        super.setAllowlist(
            0,
            borrowersArray
        );

        assertEq(
            addToAllowlistCalled,
            true,
            "addToAllowlist not called"
        );
    }

    function test_addToAllowlist() public {

        
        super._addToAllowlist(
            0,
            borrowersArray
        );

        bool isAllowed = super.addressIsAllowed(0,address(borrower));

        assertEq(
            isAllowed,
            true,
            "Expected borrower to be allowed"
        );
    }



    //overrides 

    function _addToAllowlist( 
        uint256 _commitmentId,
        address[] calldata _addressList
    ) internal override {
        addToAllowlistCalled = true;
    }

   

 /*   function test_acceptCommitmentWithBorrowersArray_valid() public {
        uint256 commitmentId = 0;

        Commitment storage commitment = _createCommitment(
            CommitmentCollateralType.ERC20,
            maxAmount
        );

        lender._updateCommitmentBorrowers(commitmentId, borrowersArray);

        uint256 bidId = borrower._acceptCommitment(
            commitmentId,
            0, //principal
            maxAmount, //collateralAmount
            0, //collateralTokenId
            address(collateralToken),
            minInterestRate,
            maxLoanDuration
        );

        assertEq(
            acceptBidWasCalled,
            true,
            "Expect accept bid called after exercise"
        );
    }

    function test_acceptCommitmentWithBorrowersArray_invalid() public {
        uint256 commitmentId = 0;

        Commitment storage commitment = _createCommitment(
            CommitmentCollateralType.ERC20,
            maxAmount
        );

        lender._updateCommitmentBorrowers(commitmentId, borrowersArray);

        bool acceptCommitAsMarketOwnerFails;

        try
            marketOwner._acceptCommitment(
                commitmentId,
                100, //principal
                maxAmount, //collateralAmount
                0, //collateralTokenId
                address(collateralToken),
                minInterestRate,
                maxLoanDuration
            )
        {} catch {
            acceptCommitAsMarketOwnerFails = true;
        }

        assertEq(
            acceptCommitAsMarketOwnerFails,
            true,
            "Should fail when accepting as invalid borrower"
        );

        lender._updateCommitmentBorrowers(commitmentId, emptyArray);

        acceptBidWasCalled = false;

        marketOwner._acceptCommitment(
            commitmentId,
            0, //principal
            maxAmount, //collateralAmount
            0, //collateralTokenId
            address(collateralToken),
            minInterestRate,
            maxLoanDuration
        );

        assertEq(
            acceptBidWasCalled,
            true,
            "Expect accept bid called after exercise"
        );
    }

    function test_acceptCommitmentWithBorrowersArray_reset() public {
        uint256 commitmentId = 0;

        Commitment storage commitment = _createCommitment(
            CommitmentCollateralType.ERC20,
            maxAmount
        );

        lender._updateCommitmentBorrowers(commitmentId, borrowersArray);

        lender._updateCommitmentBorrowers(commitmentId, emptyArray);

        marketOwner._acceptCommitment(
            commitmentId,
            0, //principal
            maxAmount, //collateralAmount
            0, //collateralTokenId
            address(collateralToken),
            minInterestRate,
            maxLoanDuration
        );

        assertEq(
            acceptBidWasCalled,
            true,
            "Expect accept bid called after exercise"
        );
    }*/


}
