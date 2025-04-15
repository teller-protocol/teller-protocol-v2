// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
 
interface ILenderCommitmentGroupSharesIntegrated is IERC20 {


    
    function initialize( )  external ;  


    function mint(address _recipient, uint256 _amount ) external   ;
    function burn(address _burner, uint256 _amount ) external   ;

    function getSharesLastTransferredAt(address owner )  external view returns (uint256)  ;


}
