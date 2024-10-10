// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

 
 

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

import "../interfaces/IHasProtocolPausingManager.sol";



abstract contract HasProtocolPausingManager is Initializable, ContextUpgradeable, IHasProtocolPausingManager, IPausableTimestamp {
  

    bool private _reserved0;// _paused.. Deprecated , handled by pausing manager 

    address private _protocolPausingManager;
 
    




     modifier onlyPauserRoleOrOwner() {

        require( pauserRoleBearer[_msgSender()] ||  owner() == _msgSender(), "Requires role: Pauser");
       

        _;
    }


    modifier whenLiquidationsNotPaused() {
        require(!liquidationsPaused, "Liquidations are paused");
      
        _;
    }

    //rename to when protocol not paused ?
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }




    function __HasProtocolPausingManager_init(address protocolPausingManager, address newOwner) internal onlyInitializing {
        _protocolPausingManager == protocolPausingManager ;
        OwnableUpgradeable(_protocolPausingManager).__Ownable_init();
        OwnableUpgradeable(_protocolPausingManager).transferOwnership(newOwner);
    }


    function getProtocolPausingManager() public view returns (address){

        return _protocolPausingManager;
    }

    function getLastUnpausedAt() 
    external view 
    returns (uint256) {

        return IPausableTimestamp(_protocolPausingManager).getLastUnpausedAt();

    } 





    /*

 

    
    function pauseLiquidations() public virtual onlyPauser {
        liquidationsPaused = true;
    }
 
    function unpauseLiquidations() public virtual onlyPauser {
         liquidationsPaused = false;
    }




    */






















    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;
}
