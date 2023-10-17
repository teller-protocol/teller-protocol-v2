// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMarketRegistry {
    function isMarketOpen(uint256 _marketId) external view returns (bool);

    function isMarketClosed(uint256 _marketId) external view returns (bool);

    function getMarketOwner(uint256 _marketId) external view returns (address);

    function getMarketplaceFee(uint256 _marketId)
        external
        view
        returns (uint16);

    function isVerifiedBorrower(uint256 _marketId, address _borrower)
        external
        view
        returns (bool, bytes32);

    function isVerifiedLender(uint256 _marketId, address _lender)
        external
        view
        returns (bool, bytes32);
}
