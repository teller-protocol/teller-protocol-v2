// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface ILenderManager {

    /**
     * @notice Sets the new active lender for a loan.
     * @param _bidId The id for the loan to set.
     * @param _newLender The address of the new active lender.
     * @param _marketId The Id of the corresponding market.
     */
    function setNewLender(uint256 _bidId, address _newLender, uint256 _marketId) external;

    /**
     * @notice Returns the address of the lender that owns a given loan/bid.
     * @param _bidId The id of the bid to return the lender for
     * @return lender_ The address of the lender.
     */
    function getActiveLoanLender(uint256 _bidId)
        external
        returns (address);
}