// SPDX-Licence-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// Contracts
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./CollateralEscrowV1.sol";

// Interfaces
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "../interfaces/escrow/ICollateralEscrowFactory.sol";

contract CollateralEscrowFactory is OwnableUpgradeable, ICollateralEscrowFactory {

    address private _collateralEscrowBeacon;
    mapping(uint256 => address) public _escrows; // bidIds -> collateralEscrow
    // biIds -> validated collateral info
    mapping(uint256 => Collateral) _bidCollaterals;

    /* Events */
    event CollateralEscrowDeployed(uint256 _bidId, address _collateralEscrow);
    event CollateralValidated(uint256 _bidId, address _collateralAddress, uint256 _amount);

    /**
     * @notice Initializes the escrow factory.
     * @param _collateralEscrowBeacon The address of the escrow implementation.
     */
    constructor(
        address _collateralEscrowBeacon
    ) {
        _collateralEscrowBeacon = _collateralEscrowBeacon;
    }

    /**
     * @notice Checks the validity of a borrower's collateral balance.
     * @param _bidId The id of the associated bid.
     * @param _borrowerAddress The address of the borrower
     * @param _collateralAddress The contract address of the asset being put up as collateral.
     * @param _collateralInfo Additional information about the collateral asset.
     * @return validation_ Boolean indicating if the collateral balance was validated.
     */
    function validateCollateral(
        uint256 _bidId,
        address _borrowerAddress,
        address _collateralAddress,
        Collateral calldata _collateralInfo
    ) external
      returns (bool validation_)
    {
        validation_ = _checkBalance(_borrowerAddress, _collateralAddress, _collateralInfo);
        if (validation_) {
            _bidCollaterals[_bidId] = _collateralInfo;
            emit CollateralValidated(_bidId, _collateralAddress, _collateralInfo._amount);
        }
    }

    /**
     * @notice Deploys a new collateral escrow.
     * @param _bidId The associated bidId of the collateral escrow.
     */
    function deployCollateralEscrow(uint256 _bidId)
        external
        returns(address)
    {
        BeaconProxy proxy_ = new BeaconProxy(
            _collateralEscrowBeacon,
            abi.encodeWithSelector(CollateralEscrowV1.initialize.selector, _bidId)
        );
        _escrows[_bidId] = address(proxy_);
        emit CollateralEscrowDeployed(_bidId, address(proxy_));
        return address(proxy_);
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

    function _checkBalance(
        address _borrowerAddress,
        address _collateralAddress,
        Collateral calldata _collateralInfo
    ) internal
      returns(bool)
    {
        CollateralType collateralType = _collateralInfo._collateralType;
        if (collateralType == CollateralType.ERC20) {
            return _collateralInfo._amount <=
                        IERC20Upgradeable(_collateralAddress)
                            .balanceOf(_borrowerAddress);
        }
        if (collateralType == CollateralType.ERC721) {
            return _borrowerAddress ==
                        IERC721Upgradeable(_collateralAddress)
                            .ownerOf(_collateralInfo._tokenId);
        }
        if (collateralType == CollateralType.ERC1155) {
            return _collateralInfo._amount <=
                        IERC1155Upgradeable(_collateralAddress)
                            .balanceOf(_borrowerAddress, _collateralInfo._tokenId);
        }
        return false;
    }
}