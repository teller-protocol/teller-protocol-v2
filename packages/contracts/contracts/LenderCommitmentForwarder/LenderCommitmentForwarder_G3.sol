pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

// Contracts
import "./LenderCommitmentForwarder_G2.sol";
import "./extensions/ExtensionsContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract LenderCommitmentForwarder_G3 is
    LenderCommitmentForwarder_G2,
    OwnableUpgradeable,
    ExtensionsContextUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _tellerV2, address _marketRegistry)
        LenderCommitmentForwarder_G2(_tellerV2, _marketRegistry)
    {}

    function initialize(address _newOwner) external initializer {
        _initializeExtensions(_newOwner);
    }

    function _initializeExtensions(address _newOwner)
        internal
        onlyInitializing
    {
        _transferOwnership(_newOwner);
    }

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ExtensionsContextUpgradeable)
        returns (address sender)
    {
        return ExtensionsContextUpgradeable._msgSender();
    }

    /*
    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ExtensionsContextUpgradeable)
        returns (bytes calldata)
    {
        return ExtensionsContextUpgradeable._msgData();
    }*/
}
