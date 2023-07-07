// SPDX-Licence-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

//import { Collateral } from "./escrow/ICollateralEscrowV1.sol";

import {Collateral} from "../bundle/interfaces/ICollateralBundle.sol";

import "./ICollateralManager.sol";

interface ICollateralManagerV1 is ICollateralManager {


    

    function checkBalances(
        address _borrowerAddress,
        Collateral[] calldata _collateralInfo
    ) external returns (bool validated_, bool[] memory checks_);

    /**
     * @notice Deploys a new collateral escrow.
     * @param _bidId The associated bidId of the collateral escrow.
     */
    function deployAndDeposit(uint256 _bidId) external;

    /**
     * @notice Gets the address of a deployed escrow.
     * @notice _bidId The bidId to return the escrow for.
     * @return The address of the escrow.
     */
    function getEscrow(uint256 _bidId) external view returns (address);

   
    

    /**
     * @notice Re-checks the validity of a borrower's collateral balance committed to a bid.
     * @param _bidId The id of the associated bid.
     * @return validation_ Boolean indicating if the collateral balance was validated.
     */
    function revalidateCollateral(uint256 _bidId) external returns (bool);

   
}
