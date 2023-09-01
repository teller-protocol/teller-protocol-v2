pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

// Contracts
import "./LenderCommitmentForwarder_G1.sol";
import "./extensions/ExtensionsContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract LenderCommitmentForwarder_G2 is
    LenderCommitmentForwarder_G1,
    OwnableUpgradeable,
    ExtensionsContextUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _tellerV2, address _marketRegistry)
        LenderCommitmentForwarder_G1(_tellerV2, _marketRegistry)
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

    function addExtension(address extension) external onlyOwner {
        _addExtension(extension);
    }

    function removeExtension(address extension) external onlyOwner {
        _removeExtension(extension);
    }

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }
}