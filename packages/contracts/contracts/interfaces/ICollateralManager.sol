// SPDX-Licence-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./escrow/ICollateralEscrowV1.sol";

interface ICollateralManager {
    enum CollateralType {
        ERC20,
        ERC721,
        ERC1155
    }

    struct Collateral {
        ICollateralEscrowV1.CollateralType _collateralType;
        uint256 _amount;
        uint256 _tokenId;
        address _collateralAddress;
    }

    /**
     * @notice Checks the validity of a borrower's collateral balance.
     * @param _bidId The id of the associated bid.
     * @param _borrowerAddress The address of the borrower
     * @param _collateralInfo Additional information about the collateral asset.
     * @return validation_ Boolean indicating if the collateral balance was validated.
     */
    function validateCollateral(
        uint256 _bidId,
        address _borrowerAddress,
        ICollateralEscrowV1.Collateral calldata _collateralInfo
    )
    external
    returns(bool validation_);

    /**
     * @notice Deploys a new collateral escrow.
     * @param _bidId The associated bidId of the collateral escrow.
     */
    function deployAndDeposit(uint256 _bidId)
    external;

    /**
     * @notice Gets the address of a deployed escrow.
     * @notice _bidId The bidId to return the escrow for.
     * @return The address of the escrow.
     */
    function getEscrow(uint256 _bidId)
    external
    view
    returns(address);

    /**
     * @notice Gets the collateral info for a given bid id.
     * @param _bidId The bidId to return the collateral info for.
     * @return The stored collateral info.
     */
    function getCollateralInfo(uint256 _bidId)
    external
    view
    returns(ICollateralEscrowV1.Collateral memory);

    /**
     * @notice Deposits validated collateral into the created escrow for a bid.
     * @param _bidId The id of the bid to deposit collateral for.
     */
    function deposit(
        uint256 _bidId
    ) external payable;

    /**
     * @notice Withdraws deposited collateral from the created escrow of a bid.
     * @param _bidId The id of the bid to withdraw collateral for.
     */
    function withdraw(uint256 _bidId) external;
}