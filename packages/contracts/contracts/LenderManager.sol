// SPDX-Licence-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// Interfaces
import "./interfaces/ILenderManager.sol";
import "./interfaces/ITellerV2.sol";
import "./interfaces/IMarketRegistry.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

contract LenderManager is ILenderManager, Initializable, ERC2771ContextUpgradeable {
    /** Storage Variables */
    ITellerV2 public immutable tellerV2;
    IMarketRegistry public immutable marketRegistry;
    string public constant CONTRACT_VERSION = "1";
    string public upgradedToVersion;

    // Mapping of loans to current active lenders
    mapping(uint256 => address) internal _loanActiveLender;

    /** Events **/
    event NewLenderSet(address indexed newLender, uint256 bidId);

    constructor(address _protocolAddress, address _marketRegistry, address _trustedForwarder)
        ERC2771ContextUpgradeable(_trustedForwarder)
    {
        tellerV2 = ITellerV2(_protocolAddress);
        marketRegistry = IMarketRegistry(_marketRegistry);
    }

    /**
     * @notice The initializer sets the initial list of active loan lenders for TellerV2.
     * @param _initialActiveBidIds Array containing the list of bidIds.
     * @param _initialActiveLenderArray Array of the associated active lender addresses.
     */

    function initialize(
        uint256[] calldata _initialActiveBidIds,
        address[] calldata _initialActiveLenderArray
    ) external initializer {
        require(_initialActiveBidIds.length == _initialActiveLenderArray.length, "Array lengths mismatch");
        upgradedToVersion = CONTRACT_VERSION;
        for (uint i=0; i<_initialActiveBidIds.length; i++) {
            _loanActiveLender[_initialActiveBidIds[i]] = _initialActiveLenderArray[i];
        }
    }

    /**
     * @notice Sets the new active lender for a loan.
     * @param _bidId The id for the loan to set.
     * @param _newLender The address of the new active lender.
     * @param _marketId The Id of the corresponding market.
     */
    function setNewLender(uint256 _bidId, address _newLender, uint256 _marketId)
        public
        override
    {
        address currentLender = _getActiveLender(_bidId);
        require(
            currentLender == _msgSender() ||
            currentLender == address(0),
            "Not loan owner"
        );
        (bool isVerified, ) = marketRegistry.isVerifiedLender(_marketId, _newLender);
        require(
            isVerified,
            "New lender not verified"
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
        external
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
        if (lender_ == address(0)) {
            lender_ = tellerV2.getLoanLender(_bidId);
        }
    }
}
