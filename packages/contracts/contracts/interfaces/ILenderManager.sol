pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

interface ILenderManager {
    /**
     * @notice Registers a new active lender for a loan, minting the nft.
     * @param _bidId The id for the loan to set.
     * @param _newLender The address of the new active lender.
     * @param _marketId The Id of the corresponding market.
     */
    function registerLoan(uint256 _bidId, address _newLender, uint256 _marketId)
    external;

    /**
     * @notice Returns the address of the lender that owns a given loan/bid.
     * @param _bidId The id of the bid to return the lender for
     * @return lender_ The address of the lender.
     */
    function getActiveLoanLender(uint256 _bidId)
    external
    view
    returns (address);
}