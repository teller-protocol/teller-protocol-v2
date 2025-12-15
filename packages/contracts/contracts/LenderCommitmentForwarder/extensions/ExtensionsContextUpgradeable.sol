// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/IExtensionsContext.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract ExtensionsContextUpgradeable is IExtensionsContext {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private userExtensions;
  
    mapping(address => bool) private globalExtensions;

    address private _TellerV2; 



    event ExtensionAdded(address extension, address sender);
    event ExtensionRevoked(address extension, address sender);

    event GlobalExtensionAdded(address extension, address sender);
    event GlobalExtensionRevoked(address extension, address sender);



    modifier onlyExtensionsProtocolOwner() { 
        require( Ownable( _TellerV2 ).owner() == _msgSender()  , "Sender not authorized");
        _;
    }



    function __initExtensionsModule(address tellerV2 )
        internal
        
    {
        _TellerV2 = tellerV2;
    }



    function hasExtension(address account, address extension)
        public
        view
        returns (bool)
    {
        return userExtensions[account][extension] || globalExtensions[extension] ;
    }

    // -----

    function addExtension(address extension) external {
        require(
            _msgSender() != extension,
            "ExtensionsContextUpgradeable: cannot approve own extension"
        );

        userExtensions[_msgSender()][extension] = true;
        emit ExtensionAdded(extension, _msgSender());
    }

    function revokeExtension(address extension) external {
        userExtensions[_msgSender()][extension] = false;
        emit ExtensionRevoked(extension, _msgSender());
    }


    // ------

    function addGlobalExtension(address extension) external onlyExtensionsProtocolOwner {
        
        globalExtensions [extension] = true;
        emit GlobalExtensionAdded(extension, _msgSender());
    }

    function revokeGlobalExtension(address extension) external onlyExtensionsProtocolOwner {
        globalExtensions[extension] = false;
        emit GlobalExtensionRevoked(extension, _msgSender());
    }

    // ------

    function _msgSender() internal view virtual returns (address sender) {
        address sender;

        if (msg.data.length >= 20) {
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }

            if (hasExtension(sender, msg.sender)) {
                return sender;
            }
        }

        return msg.sender;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}
