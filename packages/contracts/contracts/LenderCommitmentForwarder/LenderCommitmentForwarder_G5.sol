pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

// Contracts
import "./LenderCommitmentForwarder_G4.sol";
import "./extensions/ExtensionsContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract LenderCommitmentForwarder_G5 is LenderCommitmentForwarder_G4 {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _tellerV2, address _marketRegistry)
        LenderCommitmentForwarder_G4(_tellerV2, _marketRegistry)
    {}

    function getCommitmentCollateralTokenType(
        uint256 _commitmentId 
    ) public view returns (CommitmentCollateralType) {
       return commitments[_commitmentId].collateralTokenType;
    } 

}
