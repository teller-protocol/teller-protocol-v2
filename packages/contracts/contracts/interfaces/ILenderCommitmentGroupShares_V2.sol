// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
 
interface ILenderCommitmentGroupShares_V2 is IERC20 {


    
    function initialize( )  external ;  


    function mint(address _recipient, uint256 _amount ) external   ;
    function burn(address _burner, uint256 _amount ) external   ;

    function getLastTransferredAt(address owner )  external view returns (uint256)  ;


}
