// SPDX-Licence-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface ICollateralEscrowFactory {
    enum CollateralType {
        ERC20,
        ERC721,
        ERC1155
    }

    struct Collateral {
        CollateralType _collateralType;
        uint256 _amount;
        uint256 _tokenId;
    }

    /**
     * @notice Checks the validity of a borrower's collateral balance.
     * @param _bidId The id of the associated bid.
     * @param _borrowerAddress The address of the borrower
     * @param _collateralAddress The contract address of the asset being put up as collateral.
     * @param _collateralInfo Additional information about the collateral asset.
     * @return validation_ Boolean indicating if the collateral balance was validated.
     */
    function validateCollateral(
        uint256 _bidId,
        address _borrowerAddress,
        address _collateralAddress,
        Collateral calldata _collateralInfo
    )
        external
        returns(bool validation_);

    /**
     * @notice Deploys a new collateral escrow.
     * @param _bidId The associated bidId of the collateral escrow.
     */
    function deployCollateralEscrow(uint256 _bidId)
        external
        returns(address);

    /**
     * @notice Gets the address of a deployed escrow.
     * @notice _bidId The bidId to return the escrow for.
     * @return The address of the escrow.
     */
    function getEscrow(uint256 _bidId)
        external
        view
        returns(address);
}