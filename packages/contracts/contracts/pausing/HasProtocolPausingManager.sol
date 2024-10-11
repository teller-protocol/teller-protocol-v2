// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

 
 
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";


import "../interfaces/IHasProtocolPausingManager.sol";

import "../interfaces/IProtocolPausingManager.sol";

import "../interfaces/IPausableTimestamp.sol";

abstract contract HasProtocolPausingManager is Initializable, ContextUpgradeable, IHasProtocolPausingManager, IPausableTimestamp, OwnableUpgradeable {
  

    bool private _reserved0;// _paused.. Deprecated , handled by pausing manager 

    address private _protocolPausingManager;
 
     


     modifier onlyPauserRoleOrOwner() {

        require(  IProtocolPausingManager(_protocolPausingManager). isPauser(_msgSender()) , "Requires role: Pauser");
       

        _;
    }


    modifier whenLiquidationsNotPaused() {
        require(! IProtocolPausingManager(_protocolPausingManager). liquidationsPaused(), "Liquidations are paused");
      
        _;
    }

    //rename to when protocol not paused ?
    modifier whenProtocolNotPaused() {
         require(! IProtocolPausingManager(_protocolPausingManager). protocolPaused(), "Liquidations are paused");
      
        _;
    }




    function __HasProtocolPausingManager_init(address protocolPausingManager) internal onlyInitializing {
        _protocolPausingManager == protocolPausingManager ;
        //OwnableUpgradeable(_protocolPausingManager).__Ownable_init();
        //OwnableUpgradeable(_protocolPausingManager).transferOwnership(newOwner); //effectively same as ownable init 
    }


    function getProtocolPausingManager() public view returns (address){

        return _protocolPausingManager;
    }

  
     function isPauser(address _address) public view returns (bool){

        return IProtocolPausingManager(_protocolPausingManager). isPauser(_address) ;
    }

    function getLastUnpausedAt() 
    external view 
    returns (uint256) {

        return IPausableTimestamp(_protocolPausingManager).getLastUnpausedAt();

    } 



 




    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;
}
