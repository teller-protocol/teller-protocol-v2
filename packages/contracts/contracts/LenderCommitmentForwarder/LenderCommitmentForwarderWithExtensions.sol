pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

// Contracts
import "../LenderCommitmentForwarder.sol";
import "../utils/ExtensionsContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract LenderCommitmentForwarderWithExtensions is
    LenderCommitmentForwarder,
    OwnableUpgradeable,
    ExtensionsContextUpgradeable
{
    constructor(address _tellerV2, address _marketRegistry)
        LenderCommitmentForwarder(_tellerV2, _marketRegistry)
    {}

    function initializeExtensions(address _newOwner) public reinitializer(2) {
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
