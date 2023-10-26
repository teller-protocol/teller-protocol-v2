// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

 enum CommitmentCollateralType {
        NONE, // no collateral required
        ERC20,
        ERC721,
        ERC1155,
        ERC721_ANY_ID,
        ERC1155_ANY_ID,
        ERC721_MERKLE_PROOF,
        ERC1155_MERKLE_PROOF
    }

interface ISmartCommitment {

    function collateralTokenAddress() external view returns (address);
    function minInterestRate() external view returns (uint16);
    function maxDuration() external view returns (uint32);
    function isAvailableToBorrow(uint256 _principalAmount) external view returns (bool);
    function isAllowedToBorrow(address borrower) external view returns (bool);
    function getRequiredCollateral(uint256 _principalAmount) external view returns (uint256);
    function getCollateralTokenType() external view returns (CommitmentCollateralType);
    function getCollateralTokenId() external view returns (uint256);
    function withdrawFundsForAcceptBid(uint256 _principalAmount) external;

    function marketId() external view returns (uint256);
    function principalTokenAddress() external view returns (address);
    

    // Add any other methods that are needed based on your contract logic
}
