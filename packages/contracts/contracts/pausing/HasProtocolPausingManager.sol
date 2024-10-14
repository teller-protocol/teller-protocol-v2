// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

 
 
//import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
 

import "../interfaces/IHasProtocolPausingManager.sol";

import "../interfaces/IProtocolPausingManager.sol";
 

abstract contract HasProtocolPausingManager 
    is  
    IHasProtocolPausingManager    
    {
  

    bool private __paused;// .. Deprecated , handled by pausing manager 

    address private _protocolPausingManager; // 20 bytes, gap will start at new slot 
  

    modifier whenLiquidationsNotPaused() {
        require(! IProtocolPausingManager(_protocolPausingManager). liquidationsPaused(), "Liquidations paused" );
      
        _;
    }

    //rename to when protocol not paused ?
    modifier whenProtocolNotPaused() {
         require(! IProtocolPausingManager(_protocolPausingManager). protocolPaused(), "Protocol paused" );
      
        _;
    }
 

        //onlyinitializing? 
    function _setProtocolPausingManager(address protocolPausingManager) internal {
        _protocolPausingManager = protocolPausingManager ;
    }


    function getProtocolPausingManager() public view returns (address){

        return _protocolPausingManager;
    }

     

 

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;
}
