// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Libraries
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "../escrow/CollateralEscrowV1.sol";
import "../interfaces/escrow/ICollateralEscrowV1.sol";

library EscrowLib {

    /* Events */
    event CollateralEscrowDeployed(uint256 _bidId, address _collateralEscrow);
    event CollateralValidated(uint256 _bidId, address _collateralAddress, uint256 _amount);

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
    ) external
    returns (bool validation_)
    {
        validation_ = _checkBalance(_borrowerAddress, _collateralInfo);
        if (validation_) {
            emit CollateralValidated(_bidId, _collateralInfo._collateralAddress, _collateralInfo._amount);
        }
    }

    /**
     * @notice Deploys a new collateral escrow.
     * @param _bidId The associated bidId of the collateral escrow.
     */
    function deployCollateralEscrow(uint256 _bidId, address collateralEscrowBeacon)
    external
    returns(address)
    {
        BeaconProxy proxy_ = new BeaconProxy(
            collateralEscrowBeacon,
            abi.encodeWithSelector(ICollateralEscrowV1.initialize.selector, _bidId)
        );

        emit CollateralEscrowDeployed(_bidId, address(proxy_));
        return address(proxy_);
    }

    function _checkBalance(
        address _borrowerAddress,
        ICollateralEscrowV1.Collateral calldata _collateralInfo
    ) internal
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