// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/IExtensionsContext.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

abstract contract ExtensionsContextUpgradeable is ERC2771ContextUpgradeable, IExtensionsContext {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    EnumerableSetUpgradeable.AddressSet private extensions;
    EnumerableSetUpgradeable.AddressSet private blockedExtensions;
    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private extensionApprovals;

    event ExtensionAdded(address extension);
    event ExtensionBlocked(address extension);
    event ExtensionApproved(address extension, address sender);
    event ExtensionRevoked(address extension, address sender);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() ERC2771ContextUpgradeable(address(0)) {}

    function isTrustedForwarder(address forwarder)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            !blockedExtensions.contains(forwarder) &&
            extensions.contains(forwarder) &&
            extensionApprovals[_msgSender()][forwarder];
    }

    function isExtensionAdded(address extension) public view returns (bool) {
        return extensions.contains(extension);
    }

    function isExtensionBlocked(address extension) public view returns (bool) {
        return blockedExtensions.contains(extension);
    }

    function hasApprovedExtension(address extension, address account) public view returns (bool) {
        return extensionApprovals[account][extension];
    }

    function approveExtension(address extension) external {
        require(
            _msgSender() != extension,
            "ExtensionsContextUpgradeable: cannot approve own extension"
        );
        require(
            extensions.contains(extension),
            "ExtensionsContextUpgradeable: extension not added"
        );
        extensionApprovals[_msgSender()][extension] = true;
        emit ExtensionApproved(extension, _msgSender());
    }

    function revokeExtension(address extension) external {
        extensionApprovals[_msgSender()][extension] = false;
        emit ExtensionRevoked(extension, _msgSender());
    }

    function _addExtension(address extension) internal {
        require(
            !blockedExtensions.contains(extension),
            "ExtensionsContextUpgradeable: extension blocked"
        );
        require(
            !extensions.contains(extension),
            "ExtensionsContextUpgradeable: extension already added"
        );
        extensions.add(extension);
        emit ExtensionAdded(extension);
    }

    function _blockExtension(address extension) internal {
        require(
            extensions.contains(extension),
            "ExtensionsContextUpgradeable: extension not added"
        );
        extensions.remove(extension);
        blockedExtensions.add(extension);
        emit ExtensionBlocked(extension);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}
