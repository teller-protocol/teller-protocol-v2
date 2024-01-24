pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

// Contracts
import "./LenderCommitmentForwarder_U1.sol";
import "./extensions/ExtensionsContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract LenderCommitmentForwarder_G4 is
    ExtensionsContextUpgradeable, //make sure this is here to allow upgradeability
    LenderCommitmentForwarder_U1
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _tellerV2, address _marketRegistry, address _uniswapV3Factory)
        LenderCommitmentForwarder_U1(_tellerV2, _marketRegistry,_uniswapV3Factory)
    {}

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ExtensionsContextUpgradeable)
        returns (address sender)
    {
        return ExtensionsContextUpgradeable._msgSender();
    }
}
