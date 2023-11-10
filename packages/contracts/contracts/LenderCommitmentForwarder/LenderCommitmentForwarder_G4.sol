pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

// Contracts
import "./LenderCommitmentForwarder_G3.sol";
import "./extensions/ExtensionsContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract LenderCommitmentForwarder_G4 is LenderCommitmentForwarder_G3 {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _tellerV2, address _marketRegistry)
        LenderCommitmentForwarder_G3(_tellerV2, _marketRegistry)
    {}

    function updateCommitmentMaxPrincipal(
        uint256 _commitmentId,
        uint256 _maxPrincipal
    ) public commitmentLender(_commitmentId) {
        Commitment storage _commitment = commitments[_commitmentId];

        _commitment.maxPrincipal = _maxPrincipal;

        validateCommitment(_commitment);

        emit UpdatedCommitment(
            _commitmentId,
            _commitment.lender,
            _commitment.marketId,
            _commitment.principalTokenAddress,
            _commitment.maxPrincipal
        );
    }

    function updateCommitmentExpiration(
        uint256 _commitmentId,
        uint32 _expiration
    ) public commitmentLender(_commitmentId) {
        Commitment storage _commitment = commitments[_commitmentId];

        _commitment.expiration = _expiration;

        validateCommitment(_commitment);

        emit UpdatedCommitment(
            _commitmentId,
            _commitment.lender,
            _commitment.marketId,
            _commitment.principalTokenAddress,
            _commitment.maxPrincipal
        );
    }

    function updateCommitmentMaxLoanDuration(
        uint256 _commitmentId,
        uint32 _duration
    ) public commitmentLender(_commitmentId) {
        Commitment storage _commitment = commitments[_commitmentId];

        _commitment.maxDuration = _duration;

        validateCommitment(_commitment);

        emit UpdatedCommitment(
            _commitmentId,
            _commitment.lender,
            _commitment.marketId,
            _commitment.principalTokenAddress,
            _commitment.maxPrincipal
        );
    }
}
