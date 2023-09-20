pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

// Contracts
import "./LenderCommitmentForwarder_G2.sol";
import "./extensions/ExtensionsContextUpgradeable.sol";

contract LenderCommitmentForwarder_G3 is
    LenderCommitmentForwarder_G2,
    ExtensionsContextUpgradeable
{
    mapping(address => address) public extensionOwner;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _tellerV2, address _marketRegistry)
        LenderCommitmentForwarder_G2(_tellerV2, _marketRegistry)
    {
        _disableInitializers();
    }

    function initialize() external initializer {}

    function addExtension(address extension) external {
        _addExtension(extension);
        extensionOwner[extension] = _msgSender();
    }

    function removeExtension(address extension) external {
        require(
            extensionOwner[extension] == _msgSender(),
            "ExtensionsContextUpgradeable: only owner can remove extension"
        );
        _removeExtension(extension);
        extensionOwner[extension] = address(0);
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
