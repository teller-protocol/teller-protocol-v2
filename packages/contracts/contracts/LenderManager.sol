// SPDX-Licence-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// Interfaces
import "./interfaces/ILenderManager.sol";
import "./interfaces/ITellerV2.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract LenderManager is ILenderManager, Initializable {

    /** Storage Variables */
    ITellerV2 public tellerV2;

    // Mapping of loans to current active lenders
    mapping(uint256 => address) internal _loanActiveLender;

    /**
     * @notice Initializes the proxy.
     */
    function initialize(address _tellerV2) external initializer {
        tellerV2 = ITellerV2(_tellerV2);
    }

    /**
     * @notice Sets the new active lender for a loan.
     * @param _bidId The id for the loan to set.
     * @param _newLender The address of the new active lender.
     */
    function setNewLender(uint256 _bidId, address _newLender)
        public
        override
    {
        _loanActiveLender[_bidId] = _newLender;
    }

    /**
     * @notice Returns the address of the lender that owns a given loan/bid.
     * @param _bidId The id of the bid to return the lender for
     * @return lender_ The address of the lender.
     */
    function getActiveLoanLender(uint256 _bidId)
        public
        override
        returns (address)
    {
        return _loanActiveLender[_bidId];
    }

}