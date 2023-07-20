// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

abstract contract ExtensionsContextUpgradeable is ERC2771ContextUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    EnumerableSetUpgradeable.AddressSet internal extensions;

    event ExtensionAdded(address extension);
    event ExtensionRemoved(address extension);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() ERC2771ContextUpgradeable(address(0)) {}

    function isTrustedForwarder(address forwarder)
        public
        view
        virtual
        override
        returns (bool)
    {
        return extensions.contains(forwarder);
    }

    function _addExtension(address extension) internal {
        require(
            !extensions.contains(extension),
            "ExtensionsContextUpgradeable: extension already added"
        );
        extensions.add(extension);
        emit ExtensionAdded(extension);
    }

    function _removeExtension(address extension) internal {
        require(
            extensions.contains(extension),
            "ExtensionsContextUpgradeable: extension not added"
        );
        extensions.remove(extension);
        emit ExtensionRemoved(extension);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
