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


    struct AcceptFundPositionParams {
        uint256 positionId;
        uint256 principalAmount;
        uint256 collateralAmount;
    }
interface ISmartCommitment {
    function getPrincipalTokenAddress() external view returns (address);

    function getMarketId() external view returns (uint256);

    function getCollateralTokenAddress() external view returns (address);

    function getCollateralTokenType()
        external
        view
        returns (CommitmentCollateralType);

    function getCollateralTokenId() external view returns (uint256);

    function getMinInterestRate() external view returns (uint16);

    function getMaxLoanDuration() external view returns (uint32);

 /*
    function getPrincipalAmountAvailableToBorrow()
        external
        view
        returns (uint256);

   function getRequiredCollateral(uint256 _principalAmount)
        external
        view
        returns (uint256);
        */

    function isAllowedToBorrow(address borrower) external view returns (bool);

    function acceptFundsForAcceptBid(
        address _borrower,
        AcceptFundPositionParams[] memory acceptPositions,

        uint32 _loanDuration,
        uint16 _interestRate
    ) external;
}
