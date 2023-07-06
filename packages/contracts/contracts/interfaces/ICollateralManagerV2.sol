// SPDX-Licence-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
 

 //use TokenBundle 
/*
enum CollateralType {
    ERC20,
    ERC721,
    ERC1155
}

struct Collateral {
    CollateralType _collateralType;
    uint256 _amount;
    uint256 _tokenId;
    address _collateralAddress;
}*/

interface ICollateralManagerV2 {


 
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
