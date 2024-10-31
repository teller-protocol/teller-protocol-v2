// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import {IHypernativeOracle} from "../interfaces/oracleprotection/IHypernativeOracle.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


import {IOracleProtectionManager} from "../interfaces/oracleprotection/IOracleProtectionManager.sol";
 
//can go on the SCF 
abstract contract OracleProtectionManager is IOracleProtectionManager, OwnableUpgradeable{
    bytes32 private constant HYPERNATIVE_ORACLE_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.hypernative.oracle")) - 1);
  //  bytes32 private constant HYPERNATIVE_ADMIN_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.hypernative.admin")) - 1);
    bytes32 private constant HYPERNATIVE_MODE_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.hypernative.is_strict_mode")) - 1);
    
   // event OracleAdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event OracleAddressChanged(address indexed previousOracle, address indexed newOracle);

   
/*
    modifier onlyOracleAdmin() {
        require(msg.sender == owner(), "OracleProtected: caller is not the oracle admin");
        _;
    }


    constructor(address _oracle) {
        _changeOracleAdmin(msg.sender);
        require(_oracle != address(0), "Oracle address cannot be initialized to 0");
        setOracle(_oracle); 
    }
    */

    function oracleRegister(address _account) public virtual {
        address oracleAddress = _hypernativeOracle();
        IHypernativeOracle oracle = IHypernativeOracle(oracleAddress);
        if  (hypernativeOracleIsStrictMode()) {
            oracle.registerStrict(_account);
        }
        else {
            oracle.register(_account);
        }
    }




     function isOracleApproved(address _msgSender) external returns (bool) {
        address oracleAddress = _hypernativeOracle();
        if (oracleAddress == address(0)) { 
            return true;
        }
        IHypernativeOracle oracle = IHypernativeOracle(oracleAddress);
        if (oracle.isBlacklistedContext(_msgSender, tx.origin) || !oracle.isTimeExceeded(_msgSender)) {
            return false;
        }
        return true;
     }

    function isOracleApprovedAllowEOA(address _msgSender) external returns (bool){
        address oracleAddress = _hypernativeOracle();
        if (oracleAddress == address(0)) {
             
            return true;
        }

        IHypernativeOracle oracle = IHypernativeOracle(oracleAddress);
        if (oracle.isBlacklistedAccount(msg.sender) || msg.sender != tx.origin) {
            return false;
        } 
        return true ;
    }
    
    
    
    
    /**
     * @dev Admin only function, sets new oracle admin. set to address(0) to revoke oracle
     */
    function setOracle(address _oracle) public onlyOwner() {
        address oldOracle = _hypernativeOracle();
        _setAddressBySlot(HYPERNATIVE_ORACLE_STORAGE_SLOT, _oracle);
        emit OracleAddressChanged(oldOracle, _oracle);
    }

    function setIsStrictMode(bool _mode) public onlyOwner() {
        _setValueBySlot(HYPERNATIVE_MODE_STORAGE_SLOT, _mode ? 1 : 0);
    }


    //admin is just always the owner() now 
	/*
    function changeOracleAdmin(address _newAdmin) public onlyOwner() {
        _changeOracleAdmin(_newAdmin);
    }
	

    function _changeOracleAdmin(address _newAdmin) internal {
        address oldAdmin = hypernativeOracleAdmin();
        _setAddressBySlot(HYPERNATIVE_ADMIN_STORAGE_SLOT, _newAdmin);
        emit OracleAdminChanged(oldAdmin,  _newAdmin);
    }
*/

    function _setAddressBySlot(bytes32 slot, address newAddress) internal {
        assembly {
            sstore(slot, newAddress)
        }
    }

    function _setValueBySlot(bytes32 _slot, uint256 _value) internal {
        assembly {
            sstore(_slot, _value)
        }
    }


   /* function hypernativeOracleAdmin() public view returns (address) {
        return _getAddressBySlot(HYPERNATIVE_ADMIN_STORAGE_SLOT);
    }*/

    function hypernativeOracleIsStrictMode() public view returns (bool) {
        return _getValueBySlot(HYPERNATIVE_MODE_STORAGE_SLOT) == 1;
    }

    function _getAddressBySlot(bytes32 slot) internal view returns (address addr) {
        assembly {
            addr := sload(slot)
        }
    }

    function _getValueBySlot(bytes32 _slot) internal view returns (uint256 _value) {
        assembly {
            _value := sload(_slot)
        }
    }

    function _hypernativeOracle() private view returns (address) {
        return _getAddressBySlot(HYPERNATIVE_ORACLE_STORAGE_SLOT);
    }
}