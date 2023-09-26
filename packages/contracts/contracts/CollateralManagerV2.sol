pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

/*

1. During submitBid, the collateral will be Committed (?) using the 'collateral validator'

2. During acceptBid, the collateral gets bundled into the CollateralBundler which mints an NFT (the bundle) which then gets transferred into this contract 


This collateral manager will only accept collateral bundles. 

*/

// Contracts
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Libraries
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

// Interfaces
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "./interfaces/ICollateralManagerV2.sol";
//import { Collateral, CollateralType, ICollateralEscrowV1 } from "./interfaces/escrow/ICollateralEscrowV1.sol";
import "./interfaces/ITellerV2.sol";
import "./bundle/TokenStore.sol";

import "./bundle/interfaces/ICollateralBundle.sol";

/*

This contract is a token store which stores bundles.
The bid id == the bundle id. 

If the bundle exists and is owned by this contract, we know the collateral is held. 

*/

contract CollateralManagerV2 is
    ContextUpgradeable,
    TokenStore,
    ICollateralManagerV2
{
    /* Storage */
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    ITellerV2 public tellerV2;

    // bidIds -> collateralEscrow
    //mapping(uint256 => address) public _escrows;

    // bidIds -> collateralBundleId
    //mapping(uint256 => CollateralInfo) internal _committedBidCollateral;

    // bidIds -> collateralBundleInfo
    //this just bridges the gap between submitBid and acceptBid
    mapping(uint256 => ICollateralBundle.CollateralBundleInfo)
        internal _committedBidCollateral;

    /* Events */
    event CollateralEscrowDeployed(uint256 _bidId, address _collateralEscrow);

    //add events back !!
    event CollateralCommitted(
        uint256 _bidId,
        CollateralType _type,
        address _collateralAddress,
        uint256 _amount,
        uint256 _tokenId
    );
    event CollateralClaimed(uint256 _bidId);
    event CollateralDeposited(
        uint256 _bidId,
        CollateralType _type,
        address _collateralAddress,
        uint256 _amount,
        uint256 _tokenId
    );
    event CollateralWithdrawn(
        uint256 _bidId,
        CollateralType _type,
        address _collateralAddress,
        uint256 _amount,
        uint256 _tokenId,
        address _recipient
    );

    /* Modifiers */
    modifier onlyTellerV2() {
        require(_msgSender() == address(tellerV2), "Sender not authorized");
        _;
    }

    /* External Functions */

    /**
     * @notice Initializes the collateral manager.
     * @param _tellerV2 The address of the protocol.
     */
    function initialize(address _tellerV2) external initializer {
        tellerV2 = ITellerV2(_tellerV2);
        // __Ownable_init_unchained();
    }

    /**
     * @notice Checks to see if a bid is backed by collateral.
     * @param _bidId The id of the bid to check.
     */

    function isBidCollateralBacked(uint256 _bidId)
        public view
        virtual
        returns (bool)
    {
        return _committedBidCollateral[_bidId].count > 0;
    }

    /**
     * @notice Checks the validity of a borrower's multiple collateral balances and commits it to a bid.
     * @param _bidId The id of the associated bid.
     * @param _collateralInfo Additional information about the collateral assets.
     * @return validation_ Boolean indicating if the collateral balances were validated.
     */
    function commitCollateral(
        uint256 _bidId,
        Collateral[] calldata _collateralInfo
    ) 
    public
    onlyTellerV2 
    returns (bool validation_) 
    {
        address borrower = tellerV2.getLoanBorrower(_bidId);
        require(borrower != address(0), "Loan has no borrower");
        (validation_, ) = checkBalances(borrower, _collateralInfo);

        //if the collateral info is valid, call commitCollateral for each one
        if (validation_) {
            for (uint256 i; i < _collateralInfo.length; i++) {
                Collateral memory info = _collateralInfo[i];
                _commitCollateral(_bidId, info);
            }
        }
    }

    /**
     * @notice Deploys a new collateral escrow and deposits collateral.
     * @param _bidId The associated bidId of the collateral escrow.
     */

    //used to be 'deploy and deposit'
    function depositCollateral(uint256 _bidId ) 
    external
     onlyTellerV2 
     {
        Collateral[] memory _committedCollateral = getCollateralInfo(_bidId);

        //address borrower = getBorrowerForBid(_bidId); //FIX ME
        address borrower = tellerV2.getLoanBorrower(_bidId);
        
        _storeTokens(borrower, _committedCollateral, _bidId);

        //emit CollateralDeposited!
    }

    /**
     * @notice Gets the address of a deployed escrow.
     * @notice _bidId The bidId to return the escrow for.
     * @return The address of the escrow.
     */
    /* function getEscrow(uint256 _bidId) external view returns (address) {
        return _escrows[_bidId];
    }*/

    /**
     * @notice Gets the collateral info for a given bid id.
     * @param _bidId The bidId to return the collateral info for.
     * @return infos_ The stored collateral info.
     */

    //use getBundleInfo instead

    function getCollateralInfo(uint256 _bidId)
        public
        view
        returns (Collateral[] memory infos_)
    {
        /*  CollateralInfo storage collateral = _bidCollaterals[_bidId];
        address[] memory collateralAddresses = collateral
            .collateralAddresses
            .values();
        infos_ = new Collateral[](collateralAddresses.length);
        for (uint256 i; i < collateralAddresses.length; i++) {
            infos_[i] = collateral.collateralInfo[collateralAddresses[i]];
        }*/

        uint256 count = _committedBidCollateral[_bidId].count;
        infos_ = new Collateral[](count);

        for (uint256 i = 0; i < count; i++) {
            infos_[i] = _committedBidCollateral[_bidId].collaterals[i];
        }
    }

    /**
     * @notice Gets the collateral asset amount for a given bid id on the TellerV2 contract.
     * @param _bidId The ID of a bid on TellerV2.
     * @param _collateralAddress An address used as collateral.
     * @return amount_ The amount of collateral of type _collateralAddress.
     */
    function getCollateralAmount(uint256 _bidId, address _collateralAddress)
        public
        view
        returns (uint256 amount_)
    {
        Collateral memory token_data = getTokenOfBundle(_bidId, 0); // first slot

        if (token_data._collateralAddress != _collateralAddress) return 0; // not as expected

        amount_ = token_data._amount;
    }

    /**
     * @notice Withdraws deposited collateral from the created escrow of a bid that has been successfully repaid.
     * @param _bidId The id of the bid to withdraw collateral for.
     */
    function withdraw(uint256 _bidId) external {
        BidState bidState = tellerV2.getBidState(_bidId);

        require(bidState == BidState.PAID, "Loan has not been paid");

        _withdraw(_bidId, tellerV2.getLoanBorrower(_bidId));

        emit CollateralClaimed(_bidId);
    }

    /**
     * @notice Withdraws deposited collateral from the created escrow of a bid that has been CLOSED after being defaulted.
     * @param _bidId The id of the bid to withdraw collateral for.
     */
    function lenderClaimCollateral(uint256 _bidId) external onlyTellerV2 {
        if (isBidCollateralBacked(_bidId)) {
            BidState bidState = tellerV2.getBidState(_bidId);

            require(
                bidState == BidState.CLOSED,
                "Loan has not been closed"
            );

            _withdraw(_bidId, tellerV2.getLoanLender(_bidId));
            emit CollateralClaimed(_bidId);
        }
    }

    /**
     * @notice Sends the deposited collateral to a liquidator of a bid.
     * @notice Can only be called by the protocol.
     * @param _bidId The id of the liquidated bid.
     * @param _liquidatorAddress The address of the liquidator to send the collateral to.
     */
    function liquidateCollateral(uint256 _bidId, address _liquidatorAddress)
        external
        onlyTellerV2
    {
        if (isBidCollateralBacked(_bidId)) {
            BidState bidState = tellerV2.getBidState(_bidId);
            require(
                bidState == BidState.LIQUIDATED,
                "Loan has not been liquidated"
            );
            _withdraw(_bidId, _liquidatorAddress);
        }
    }

    /**
     * @notice Checks the validity of a borrower's multiple collateral balances.
     * @param _borrowerAddress The address of the borrower holding the collateral.
     * @param _collateralInfo Additional information about the collateral assets.
     */
    function checkBalances(
        address _borrowerAddress,
        Collateral[] calldata _collateralInfo
    ) public view returns (bool validated_, bool[] memory checks_) {
        return _checkBalances(_borrowerAddress, _collateralInfo, false);
    }

    /* Internal Functions */

    /**
     * @notice Withdraws collateral to a given receiver's address.
     * @param _bidId The id of the bid to withdraw collateral for.
     * @param _receiver The address to withdraw the collateral to.
     */
    function _withdraw(uint256 _bidId, address _receiver) internal virtual {
        (uint256 count, Collateral[] memory releasedTokens) = _releaseTokens(
            _receiver,
            _bidId
        );

        for (uint256 i = 0; i < count; i += 1) {
            emit CollateralWithdrawn(
                _bidId,
                releasedTokens[i]._collateralType,
                releasedTokens[i]._collateralAddress,
                releasedTokens[i]._amount,
                releasedTokens[i]._tokenId,
                _receiver
            );
        }
    }

    /**
     * @notice Checks the validity of a borrower's collateral balance and commits it to a bid.
     * @param _bidId The id of the associated bid.
     * @param _collateralInfo Additional information about the collateral asset.
     */
    function _commitCollateral(
        uint256 _bidId,
        Collateral memory _collateralInfo
    ) internal virtual {
        CollateralBundleInfo
            storage committedCollateral = _committedBidCollateral[_bidId];

        /* require(
            !collateral.collateralAddresses.contains(
                _collateralInfo._collateralAddress
            ),
            "Cannot commit multiple collateral with the same address"
        );*/
        require(
            _collateralInfo._collateralType != CollateralType.ERC721 ||
                _collateralInfo._amount == 1,
            "ERC721 collateral must have amount of 1"
        );

        /*collateral.collateralAddresses.add(_collateralInfo._collateralAddress);
        collateral.collateralInfo[
            _collateralInfo._collateralAddress
        ] = _collateralInfo;*/

        uint256 new_count = committedCollateral.count + 1;

        committedCollateral.count = new_count;
        committedCollateral.collaterals[new_count] = _collateralInfo;

        emit CollateralCommitted(
            _bidId,
            _collateralInfo._collateralType,
            _collateralInfo._collateralAddress,
            _collateralInfo._amount,
            _collateralInfo._tokenId
        );
    }

    /**
     * @notice Checks the validity of a borrower's multiple collateral balances.
     * @param _borrowerAddress The address of the borrower holding the collateral.
     * @param _collateralInfo Additional information about the collateral assets.
     * @param _shortCircut  if true, will return immediately until an invalid balance
     */
    function _checkBalances(
        address _borrowerAddress,
        Collateral[] memory _collateralInfo,
        bool _shortCircut
    ) internal virtual returns (bool validated_, bool[] memory checks_) {
        checks_ = new bool[](_collateralInfo.length);
        validated_ = true;
        for (uint256 i; i < _collateralInfo.length; i++) {
            bool isValidated = _checkBalance(
                _borrowerAddress,
                _collateralInfo[i]
            );
            checks_[i] = isValidated;
            if (!isValidated) {
                validated_ = false;
                //if short circuit is true, return on the first invalid balance to save execution cycles. Values of checks[] will be invalid/undetermined if shortcircuit is true.
                if (_shortCircut) {
                    return (validated_, checks_);
                }
            }
        }
    }

    /**
     * @notice Checks the validity of a borrower's single collateral balance.
     * @param _borrowerAddress The address of the borrower holding the collateral.
     * @param _collateralInfo Additional information about the collateral asset.
     * @return validation_ Boolean indicating if the collateral balances were validated.
     */
    function _checkBalance(
        address _borrowerAddress,
        Collateral memory _collateralInfo
    ) internal virtual returns (bool) {
        CollateralType collateralType = _collateralInfo._collateralType;

        if (collateralType == CollateralType.ERC20) {
            return
                _collateralInfo._amount <=
                IERC20Upgradeable(_collateralInfo._collateralAddress).balanceOf(
                    _borrowerAddress
                );
        } else if (collateralType == CollateralType.ERC721) {
            return
                _borrowerAddress ==
                IERC721Upgradeable(_collateralInfo._collateralAddress).ownerOf(
                    _collateralInfo._tokenId
                );
        } else if (collateralType == CollateralType.ERC1155) {
            return
                _collateralInfo._amount <=
                IERC1155Upgradeable(_collateralInfo._collateralAddress)
                    .balanceOf(_borrowerAddress, _collateralInfo._tokenId);
        } else {
            return false;
        }
    }

    // On NFT Received handlers

    function onERC721Received(address, address, uint256, bytes memory)
        public
        pure
        override
        returns (bytes4)
    {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }

    function onERC1155Received(
        address,
        address,
        uint256 id,
        uint256 value,
        bytes memory
    ) public override returns (bytes4) {
        return
            bytes4(
                keccak256(
                    "onERC1155Received(address,address,uint256,uint256,bytes)"
                )
            );
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory _ids,
        uint256[] memory _values,
        bytes memory
    ) public override returns (bytes4) {
        require(
            _ids.length == 1,
            "Only allowed one asset batch transfer per transaction."
        );
        return
            bytes4(
                keccak256(
                    "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"
                )
            );
    }
}
