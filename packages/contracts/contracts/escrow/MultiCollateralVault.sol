pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

 
import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; 


contract MultiCollateralVault is ERC721 {


   event createdVault(  );

   //tokenId => collateralInside 
   mapping(uint256 => Collateral) public vaults; 

   uint256 public vaultCount;
 

   constructor(){}


   function depositCollateral() public {

   }


   function withdrawCollateral() public {


   }


}