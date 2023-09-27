// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/**
 *  Group together arbitrary ERC20, ERC721 and ERC1155 tokens into a single bundle.
 *
 *  The `Token` struct is a generic type that can describe any ERC20, ERC721 or ERC1155 token.
 *  The `Bundle` struct is a data structure to track a group/bundle of multiple assets i.e. ERC20,
 *  ERC721 and ERC1155 tokens, each described as a `Token`.
 *
 *  Expressing tokens as the `Token` type, and grouping them as a `Bundle` allows for writing generic
 *  logic to handle any ERC20, ERC721 or ERC1155 tokens.
 */

/// @notice The type of assets that can be bundled.
enum CollateralType {
    ERC20,
    ERC721,
    ERC1155
}

/**
 *  @notice A generic interface to describe any ERC20, ERC721 or ERC1155 token.
 *  @param _collateralType     The token type (ERC20 / ERC721 / ERC1155) of the asset.
 *  @param _amount   The amount of the asset, if the asset is an ERC20 / ERC1155 fungible token.
 *  @param _tokenId       The token Id of the asset, if the asset is an ERC721 / ERC1155 NFT.
 *  @param _collateralAddress The contract address of the asset.
 *
 */
struct Collateral {
    CollateralType _collateralType;
    uint256 _amount;
    uint256 _tokenId;
    address _collateralAddress;
}

interface ICollateralBundle {
    /**
     *  @notice An internal data structure to track a group / bundle of multiple assets i.e. `Token`s.
     *
     *  @param count    The total number of assets i.e. `Collateral` in a bundle.
     *  @param collaterals   Mapping from a UID -> to a unique asset i.e. `Collateral` in the bundle.
     */
    struct CollateralBundleInfo {
        uint256 count;
        mapping(uint256 => Collateral) collaterals;
    }
}
