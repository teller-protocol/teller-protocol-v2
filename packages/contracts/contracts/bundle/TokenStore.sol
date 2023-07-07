// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @author thirdweb

//  ==========  External imports    ==========

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
 
//  ==========  Internal imports    ==========

import { Collateral,CollateralType } from "./interfaces/ICollateralBundle.sol";
import { TokenBundle, ICollateralBundle } from "./TokenBundle.sol";
import "./lib/CurrencyTransferLib.sol";

/**
 *  @title   Token Store
 *  @notice  `TokenStore` contract extension allows bundling-up of ERC20/ERC721/ERC1155 and native-tokan assets
 *           and provides logic for storing, releasing, and transferring them from the extending contract.
 *  @dev     See {CurrencyTransferLib}
 */

contract TokenStore is TokenBundle, ERC721HolderUpgradeable, ERC1155HolderUpgradeable {
    /// @dev The address of the native token wrapper contract.
    /*address internal immutable nativeTokenWrapper;

    constructor(address _nativeTokenWrapper) {
        nativeTokenWrapper = _nativeTokenWrapper;
    }*/

    /// @dev Store / escrow multiple ERC1155, ERC721, ERC20 tokens.
    function _storeTokens(
        address _tokenOwner,
        Collateral[] memory _tokens,
        //string memory _uriForTokens,
        uint256 _bundleId
    ) internal {
        _createBundle(_tokens, _bundleId);
        //_setUriOfBundle(_uriForTokens, _idForTokens);
        _transferTokenBatch(_tokenOwner, address(this), _tokens);
    }

    /// @dev Release stored / escrowed ERC1155, ERC721, ERC20 tokens.
    function _releaseTokens(address _recipient, uint256 _bundleId) internal returns ( uint256, Collateral[] memory ) {
        uint256 count = getTokenCountOfBundle(_bundleId);
        Collateral[] memory tokensToRelease = new Collateral[](count);

        for (uint256 i = 0; i < count; i += 1) {
            tokensToRelease[i] = getTokenOfBundle(_bundleId, i);
        }

        _deleteBundle(_bundleId);

        _transferTokenBatch(address(this), _recipient, tokensToRelease);

        return (count,tokensToRelease);
    }

    /// @dev Transfers an arbitrary ERC20 / ERC721 / ERC1155 token.
    function _transferToken(
        address _from,
        address _to,
        Collateral memory _token
    ) internal {
        if (_token._collateralType == CollateralType.ERC20) {
            CurrencyTransferLib.transferCurrency(
                _token._collateralAddress,
                _from,
                _to,
                _token._amount
            );
        } else if (_token._collateralType == CollateralType.ERC721) {
            IERC721(_token._collateralAddress).safeTransferFrom(_from, _to, _token._tokenId);
        } else if (_token._collateralType == CollateralType.ERC1155) {
            IERC1155(_token._collateralAddress).safeTransferFrom(_from, _to, _token._tokenId, _token._amount, "");
        }
    }

    /// @dev Transfers multiple arbitrary ERC20 / ERC721 / ERC1155 tokens.
    function _transferTokenBatch(
        address _from,
        address _to,
        Collateral[] memory _tokens
    ) internal {

        //make sure this cannot cause issues 
        uint256 nativeTokenValue;
        for (uint256 i = 0; i < _tokens.length; i += 1) {
            if (_tokens[i]._collateralAddress == CurrencyTransferLib.NATIVE_TOKEN && _to == address(this)) {
                nativeTokenValue += _tokens[i]._amount;
            } else {
                _transferToken(_from, _to, _tokens[i]);
            }
        }
        if (nativeTokenValue != 0) {
            Collateral memory _nativeToken = Collateral({
                _collateralAddress: CurrencyTransferLib.NATIVE_TOKEN,
                _collateralType: CollateralType.ERC20,
                _tokenId: 0,
                _amount: nativeTokenValue
            });
            _transferToken(_from, _to, _nativeToken);
        }
    }
} 