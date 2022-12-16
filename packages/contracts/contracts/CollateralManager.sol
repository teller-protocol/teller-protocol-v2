// SPDX-Licence-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// Contracts
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Interfaces
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "./TellerV2.sol";

contract CollateralManager is OwnableUpgradeable, ICollateralManager {

    address private collateralEscrowBeacon;
    mapping(uint256 => address) public _escrows; // bidIds -> collateralEscrow
    // biIds -> validated collateral info
    mapping(uint256 => ICollateralEscrowV1.Collateral) public _bidCollaterals;
    // Boolean indicating if a bid is backed by collateral
    mapping(uint256 => bool) _isBidCollateralBacked;

    /* Events */
    event CollateralEscrowDeployed(uint256 _bidId, address _collateralEscrow);
    event CollateralValidated(uint256 _bidId, address _collateralAddress, uint256 _amount);

    /**
     * @notice Initializes the collateral manager.
     * @param _collateralEscrowBeacon The address of the escrow implementation.
     */
    function initialize(
        address _collateralEscrowBeacon
    ) external initializer {
        collateralEscrowBeacon = _collateralEscrowBeacon;
        __CollateralManager_init();
    }

    function __CollateralManager_init() internal onlyInitializing {
        __Ownable_init();
    }

    /**
     * @notice Checks the validity of a borrower's collateral balance.
     * @param _bidId The id of the associated bid.
     * @param _borrowerAddress The address of the borrower
     * @param _collateralInfo Additional information about the collateral asset.
     * @return validation_ Boolean indicating if the collateral balance was validated.
     */
    function validateCollateral(
        uint256 _bidId,
        address _borrowerAddress,
        ICollateralEscrowV1.Collateral calldata _collateralInfo
    ) external onlyOwner
    returns (bool validation_)
    {
        validation_ = _checkBalance(_borrowerAddress, _collateralInfo);
        if (validation_) {
            _bidCollaterals[_bidId] = _collateralInfo;
            emit CollateralValidated(_bidId, _collateralInfo._collateralAddress, _collateralInfo._amount);
        }
        _isBidCollateralBacked[_bidId] = validation_;
    }

    /**
     * @notice Deploys a new collateral escrow and deposits collateral.
     * @param _bidId The associated bidId of the collateral escrow.
     */
    function deployAndDeposit(uint256 _bidId)
        external
        onlyOwner
    {
        if (_isBidCollateralBacked[_bidId]) {
            BeaconProxy proxy_ = new BeaconProxy(
                collateralEscrowBeacon,
                abi.encodeWithSelector(CollateralEscrowV1.initialize.selector, _bidId)
            );
            _escrows[_bidId] = address(proxy_);
            deposit(_bidId);
            emit CollateralEscrowDeployed(_bidId, address(proxy_));
        }
    }

    /**
     * @notice Gets the address of a deployed escrow.
     * @notice _bidId The bidId to return the escrow for.
     * @return The address of the escrow.
     */
    function getEscrow(uint256 _bidId)
        external
        view
        returns(address)
    {
        return _escrows[_bidId];
    }

    /**
     * @notice Gets the collateral info for a given bid id.
     * @param _bidId The bidId to return the collateral info for.
     * @return The stored collateral info.
     */
    function getCollateralInfo(uint256 _bidId)
        external
        view
        returns(ICollateralEscrowV1.Collateral memory)
    {
        return _bidCollaterals[_bidId];
    }

    /**
     * @notice Deposits validated collateral into the created escrow for a bid.
     * @param _bidId The id of the bid to deposit collateral for.
     */
    function deposit(
        uint256 _bidId
    )
        public
        payable
        onlyOwner
    {
        // Get escrow
        ICollateralEscrowV1.Collateral memory collateralInfo = _bidCollaterals[_bidId];
        require(collateralInfo._amount > 0, 'Collateral not validated');
        address escrowAddress = _escrows[_bidId];
        ICollateralEscrowV1 collateralEscrow = ICollateralEscrowV1(escrowAddress);
        // Get bid info
        address borrower = tellerV2.getLoanBorrower(_bidId);
        // Pull collateral from borrower & deposit into escrow
        if (collateralInfo._collateralType == ICollateralEscrowV1.CollateralType.ERC20) {
            IERC20Upgradeable(collateralInfo._collateralAddress)
            .transferFrom(
                borrower,
                address(this),
                collateralInfo._amount
            );
            IERC20Upgradeable(collateralInfo._collateralAddress)
                .approve(escrowAddress, collateralInfo._amount);
            collateralEscrow.depositToken(
                collateralInfo._collateralAddress,
                collateralInfo._amount
            );
        }
        if (collateralInfo._collateralType == ICollateralEscrowV1.CollateralType.ERC721) {
            IERC721Upgradeable(collateralInfo._collateralAddress)
            .safeTransferFrom(
                borrower,
                address(this),
                collateralInfo._tokenId
            );
            collateralEscrow.depositAsset(
                ICollateralEscrowV1.CollateralType.ERC721,
                collateralInfo._collateralAddress,
                collateralInfo._amount,
                collateralInfo._tokenId
            );
        }
        if (collateralInfo._collateralType == ICollateralEscrowV1.CollateralType.ERC1155) {
            bytes memory data;
            IERC1155Upgradeable(collateralInfo._collateralAddress)
                .safeTransferFrom(
                    borrower,
                    address(this),
                    collateralInfo._tokenId,
                    collateralInfo._amount,
                    data
                );
            collateralEscrow.depositAsset(
                ICollateralEscrowV1.CollateralType.ERC1155,
                collateralInfo._collateralAddress,
                collateralInfo._amount,
                collateralInfo._tokenId
            );
        }
    }

    /**
     * @notice Withdraws deposited collateral from the created escrow of a bid.
     * @param _bidId The id of the bid to withdraw collateral for.
     */
    function withdraw(uint256 _bidId) external {
        if (_isBidCollateralBacked[_bidId]) {
            BidState bidState = TellerV2(owner()).getBidState(_bidId);
            require(
                bidState >= BidState.PAID,
                'Loan has not been repaid or liquidated'
            );
            address receiver;
            if(bidState == BidState.LIQUIDATED) {
                receiver = TellerV2(owner()).getLoanLender(_bidId);
            } else {
                receiver = TellerV2(owner()).getLoanBorrower(_bidId);
            }
            // Get collateral info
            ICollateralEscrowV1.Collateral memory collateralInfo = _bidCollaterals[_bidId];
            // Withdraw collateral from escrow and send it to bid lender
            ICollateralEscrowV1(_escrows[_bidId]).withdraw(
                collateralInfo._collateralAddress,
                collateralInfo._amount,
                receiver
            );
        }
    }

    function _checkBalance(
        address _borrowerAddress,
        ICollateralEscrowV1.Collateral calldata _collateralInfo
    )
        internal
        returns(bool)
    {
        ICollateralEscrowV1.CollateralType collateralType = _collateralInfo._collateralType;
        if (collateralType == ICollateralEscrowV1.CollateralType.ERC20) {
            return _collateralInfo._amount <=
                IERC20Upgradeable(_collateralInfo._collateralAddress)
                    .balanceOf(_borrowerAddress);
        }
        if (collateralType == ICollateralEscrowV1.CollateralType.ERC721) {
            return _borrowerAddress ==
                IERC721Upgradeable(_collateralInfo._collateralAddress)
                    .ownerOf(_collateralInfo._tokenId);
        }
        if (collateralType == ICollateralEscrowV1.CollateralType.ERC1155) {
            return _collateralInfo._amount <=
                IERC1155Upgradeable(_collateralInfo._collateralAddress)
                    .balanceOf(_borrowerAddress, _collateralInfo._tokenId);
        }
        return false;
    }
}