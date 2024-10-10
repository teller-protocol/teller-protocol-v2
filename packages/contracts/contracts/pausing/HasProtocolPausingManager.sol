// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

 
 

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
abstract contract HasProtocolPausingManager is Initializable, ContextUpgradeable {
  

    bool private _reserved0;// _paused.. Deprecated 

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






    /*

 
    function pauseProtocol() public virtual onlyPauser whenNotPaused {
        _pause();
    }

     
    function unpauseProtocol() public virtual onlyPauser whenPaused {
        _unpause();
    }


    
    function pauseLiquidations() public virtual onlyPauser {
        liquidationsPaused = true;
    }
 
    function unpauseLiquidations() public virtual onlyPauser {
         liquidationsPaused = false;
    }



    function addPauser(address _pauser) public virtual onlyOwner   {
       pauserRoleBearer[_pauser] = true;
    }


    function removePauser(address _pauser) public virtual onlyOwner {
        pauserRoleBearer[_pauser] = false;
    }


    function isPauser(address _account) public view returns(bool){
        return pauserRoleBearer[_account] ;
    }

    */






















    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;
}
