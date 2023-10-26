// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

 

contract LoanRepaymentInterestCollector  
     
{ 

     address public immutable principalToken;

    function collectInterest()
    external 
    onlyOwner
    {

        uint256 currentBalance = IERC20( principalToken ).balanceOf(address(this));

        IERC20(principalToken).transfer(  address(owner) , currentBalance );
        
    }



}