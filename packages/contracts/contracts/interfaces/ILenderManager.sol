// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface ILenderManager {
    /**
     * @notice Initializes the proxy.
     */
    function initialize(address protocolAddress) external;

    /**
     * @notice Sets the new active lender for a loan.
     * @param _bidId The id for the loan to set.
     * @param _newLender The address of the new active lender.
     */
    function setNewLender(uint256 _bidId, address _newLender) external;

    /**
     * @notice Returns the address of the lender that owns a given loan/bid.
     * @param _bidId The id of the bid to return the lender for
     * @return lender_ The address of the lender.
     */
    function getActiveLoanLender(uint256 _bidId)
        external
        returns (address);
}