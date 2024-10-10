// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;



import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../interfaces/IProtocolPausingManager.sol";

/**
 
 TODO:

 Move SCF pausing into here ??


 */
contract ProtocolPausingManager is ContextUpgradeable, OwnableUpgradeable, IProtocolPausingManager , IPausableTimestamp{
  

    bool private _protocolPaused; 
    bool private _liquidationsPaused; 
    //bool private _liquidityPoolsPaused;    


    // u8 private _currentPauseState;  //use an enum !!! 

    mapping(address => bool) public  pauserRoleBearer  ;


    uint256 private lastPausedAt;
    uint256 private lastUnpausedAt;
    
     
    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function protocolPaused() public view virtual returns (bool) {
        return _protocolPaused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

   




    function pauseProtocol() public virtual onlyPauser whenNotPaused {
          _paused = true;
        emit Paused(_msgSender());
    }

     
    function unpauseProtocol() public virtual onlyPauser whenPaused {
       _paused = false;
        emit Unpaused(_msgSender());
    }




    function getLastUnpausedAt() 
    external view 
    returns (uint256) {

        return lastUnpausedAt;

    } 




    // Role Management 


    function addPauser(address _pauser) public virtual onlyOwner   {
       pauserRoleBearer[_pauser] = true;
    }


    function removePauser(address _pauser) public virtual onlyOwner {
        pauserRoleBearer[_pauser] = false;
    }


    function isPauser(address _account) public view returns(bool){
        return pauserRoleBearer[_account] ;
    }

  
}
