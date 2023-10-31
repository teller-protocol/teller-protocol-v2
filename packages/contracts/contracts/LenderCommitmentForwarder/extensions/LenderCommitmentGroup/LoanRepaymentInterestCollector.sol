// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

 import "@openzeppelin/contracts/access/Ownable.sol";
 import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LoanRepaymentInterestCollector  
     is Ownable
{ 

     address public immutable principalToken;


    constructor( address _principalToken ){

        principalToken = _principalToken;

    }

    function collectInterest()
    external 
    onlyOwner
    {

        uint256 currentBalance = IERC20( principalToken ).balanceOf(address(this));

        IERC20(principalToken).transfer(  address(owner) , currentBalance );
        
    }



}