// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILenderCommitmentGroup {
    function initialize(
        address _principalTokenAddress,
        address _collateralTokenAddress,
        uint256 _marketId,
        uint32 _maxLoanDuration,
        uint16 _interestRateLowerBound,
        uint16 _interestRateUpperBound,
        uint16 _liquidityThresholdPercent,
        uint16 _loanToValuePercent, //essentially the overcollateralization ratio.  10000 is 1:1 baseline ?
        uint24 _uniswapPoolFee,
        uint32 _twapInterval
    )
        external
        returns (
            //uint256 _maxPrincipalPerCollateralAmount //use oracle instead

            //ILenderCommitmentForwarder.Commitment calldata _createCommitmentArgs

            address poolSharesToken
        );

    function addPrincipalToCommitmentGroup(
        uint256 _amount,
        address _sharesRecipient,
        uint256 _minAmountOut
    ) external returns (uint256 sharesAmount_);
}
