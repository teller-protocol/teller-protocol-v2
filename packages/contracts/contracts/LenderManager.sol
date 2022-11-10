// SPDX-Licence-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// Interfaces
import "./interfaces/ILenderManager.sol";
import "./interfaces/ITellerV2.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract LenderManager is ILenderManager, Initializable {
    /** Storage Variables */
    ITellerV2 public immutable tellerV2;

    // Mapping of loans to current active lenders
    mapping(uint256 => address) internal _loanActiveLender;

    /** Events **/
    event NewLenderSet(address indexed newLender, uint256 bidId);

    constructor(address _protocolAddress) {
        tellerV2 = ITellerV2(_protocolAddress);
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
        address currentLender = _getActiveLender(_bidId);
        require(
            currentLender == msg.sender ||
            currentLender == address(0),
            "Not loan owner"
        );
        if (currentLender != _newLender) {
            _loanActiveLender[_bidId] = _newLender;
            emit NewLenderSet(_newLender, _bidId);
        }
    }

    /**
     * @notice Returns the address of the lender that owns a given loan/bid.
     * @param _bidId The id of the bid to return the lender for
     * @return The address of the lender.
     */
    function getActiveLoanLender(uint256 _bidId)
        public
        override
        returns (address)
    {
        return _getActiveLender(_bidId);
    }

    /**
     * @notice Returns the address of the lender that owns a given loan/bid.
     * @param _bidId The id of the bid to return the lender for
     * @return lender_ The address of the lender.
     */
    function _getActiveLender(uint256 _bidId)
        internal
        returns (address lender_)
    {
        lender_ = _loanActiveLender[_bidId];
        if (_loanActiveLender[_bidId] == address(0)) {
            lender_ = tellerV2.getLoanLender(_bidId);
        }
    }
}
