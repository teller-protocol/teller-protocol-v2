pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

// Contracts
import "./LenderCommitmentForwarder_G2.sol";
import "./extensions/ExtensionsContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract LenderCommitmentForwarder_G3 is
    LenderCommitmentForwarder_G2,
    ExtensionsContextUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _tellerV2, address _marketRegistry)
        LenderCommitmentForwarder_G2(_tellerV2, _marketRegistry)
    {}

    /**
     * @notice Returns the TellerV2 address for protocol owner checks.
     * @dev Implements the abstract function from ExtensionsContextUpgradeable.
     * @dev Uses the immutable _tellerV2 from TellerV2MarketForwarder_G2 parent contract.
     */
    function _getTellerV2() internal view override returns (address) {
        return _tellerV2;
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
}
