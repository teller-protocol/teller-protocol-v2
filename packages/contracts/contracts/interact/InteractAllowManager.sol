// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;



import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";



import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";



import "../interfaces/IInteractAllowManager.sol";
 

/**
 
 TODO:

 Move SCF pausing into here ??


 */
contract InteractAllowManager is ContextUpgradeable, 
OwnableUpgradeable, IInteractAllowManager {
    using MathUpgradeable for uint256;
 
 

    mapping(address => bool) public  interactAdminRoleBearer  ;

    mapping(address => bool) private  interactionsAllowedFrom  ;
 


    // Events
    event InteractionsAllowed(address indexed account);
    event InteractionsRevoked(address indexed account);
    event AdminAdded(address indexed account);
    event AdminRemoved(address indexed account);

    event InteractionAllowRequested(address indexed account);
    
 
    modifier onlyInteractAdmin() {
        require( isAdmin( _msgSender()) );
        _;
    }


    //need to initialize so owner is owner (transfer ownership to safe)

    function initialize(
        
    ) external initializer {

        __Ownable_init();

    }


 // just emit an event  so offchain bots (admin) can grant access 
   function requestInteractionAllow(address _account) public virtual   {
       emit InteractionAllowRequested(_account);
    }


    function allowInteractionsFrom(address _account) public virtual onlyInteractAdmin   {
       interactionsAllowedFrom[_account] = true;
       emit InteractionsAllowed(_account);
    }


    function revokeInteractionsFrom(address _account) public virtual onlyInteractAdmin {
        interactionsAllowedFrom[_account] = false;
        emit InteractionsRevoked(_account);
    }



    function interactionAllowedFrom(address _account) public view returns(bool){
        return _isContract(_account) == false || interactionsAllowedFrom[_account] ;
    }


    // THIS IS NOT SAFE 
    function _isContract(address addr) internal view returns (bool){
       return addr.code.length > 0; 
    }


    // Role Management 



    function addAdminRole(address _account) public virtual onlyOwner   {
       interactAdminRoleBearer[_account] = true;
       emit AdminAdded(_account);
    }


    function removeAdminRole(address _account) public virtual onlyOwner {
        interactAdminRoleBearer[_account] = false;
        emit AdminRemoved(_account);
    }



    function isAdmin(address _account) public view returns(bool){
        return interactAdminRoleBearer[_account] || _account == owner() ;
    }


  
}
