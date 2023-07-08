// SPDX-Licence-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { Collateral } from "../bundle/interfaces/ICollateralBundle.sol";

interface ICollateralManager {
    /**
     * @notice Checks the validity of a borrower's collateral balance.
     * @param _bidId The id of the associated bid.
     * @param _collateralInfo Additional information about the collateral asset.
     * @return validation_ Boolean indicating if the collateral balance was validated.
     */
    function commitCollateral(
        uint256 _bidId,
        Collateral[] calldata _collateralInfo
    ) external returns (bool validation_);

    /**
     * @notice Gets the collateral info for a given bid id.
     * @param _bidId The bidId to return the collateral info for.
     * @return The stored collateral info.
     */
    function getCollateralInfo(uint256 _bidId)
        external
        view
        returns (Collateral[] memory);

    function getCollateralAmount(uint256 _bidId, address collateralAssetAddress)
        external
        view
        returns (uint256 _amount);

    /**
     * @notice Withdraws deposited collateral from the created escrow of a bid.
     * @param _bidId The id of the bid to withdraw collateral for.
     */
    function withdraw(uint256 _bidId) external;

    /**
     * @notice Sends the deposited collateral to a lender of a bid.
     * @notice Can only be called by the protocol.
     * @param _bidId The id of the liquidated bid.
     */
    function lenderClaimCollateral(uint256 _bidId) external;

    /**
     * @notice Sends the deposited collateral to a liquidator of a bid.
     * @notice Can only be called by the protocol.
     * @param _bidId The id of the liquidated bid.
     * @param _liquidatorAddress The address of the liquidator to send the collateral to.
     */
    function liquidateCollateral(uint256 _bidId, address _liquidatorAddress)
        external;
}
