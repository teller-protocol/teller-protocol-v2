// SPDX-Licence-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// Contracts
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

// Interfaces
import "./interfaces/ILenderManager.sol";
import "./interfaces/ITellerV2.sol";
import "./interfaces/IMarketRegistry.sol";

contract LenderManager is
    Initializable,
    OwnableUpgradeable,
    ERC2771ContextUpgradeable,
    ILenderManager
{
    IMarketRegistry public immutable marketRegistry;

    // Mapping of loans to current active lenders
    mapping(uint256 => address) internal _loanActiveLender;

    /** Events **/
    event NewLenderSet(address indexed newLender, uint256 bidId);

    constructor(address _trustedForwarder, address _marketRegistry)
        ERC2771ContextUpgradeable(_trustedForwarder)
    {
        _disableInitializers();
        marketRegistry = IMarketRegistry(_marketRegistry);
    }

    function initialize() external initializer {
        __LenderManager_init();
    }

    function __LenderManager_init() internal onlyInitializing {
        __Ownable_init();
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
        if (currentLender == address(0)) {
            _checkOwner();
        } else {
            require(currentLender == _msgSender(), "Not loan owner");
        }
        (bool isVerified, ) = marketRegistry.isVerifiedLender(
            _marketId,
            _newLender
        );
        require(isVerified, "New lender not verified");
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
        view
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
        view
        returns (address lender_)
    {
        lender_ = _loanActiveLender[_bidId];
        if (lender_ == address(0)) {
            lender_ = ITellerV2(owner()).getLoanLender(_bidId);
        }
    }

    /** OpenZeppelin Override Functions **/

    function _msgSender()
        internal
        view
        virtual
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (address sender)
    {
        sender = ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }
}
