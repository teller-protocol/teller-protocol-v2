// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;


//DO NOT USE ME 

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

 /*

interface ITokenBundle {
    /// @notice The type of assets that can be wrapped.
    enum TokenType {
        ERC20,
        ERC721,
        ERC1155
    }

    
    struct Token {
        address assetContract;
        TokenType tokenType;
        uint256 tokenId;
        uint256 totalAmount;
    }

     
    struct BundleInfo {
        uint256 count;
        //string uri;
        mapping(uint256 => Token) tokens;
    }
}

*/