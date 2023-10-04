// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @author thirdweb
/// https://github.com/thirdweb-dev/contracts/tree/main/contracts/multiwrap

import "./interfaces/ICollateralBundle.sol";
import "./lib/CurrencyTransferLib.sol";

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/**
 *  @title   Token Bundle
 *  @notice  `TokenBundle` contract extension allows bundling-up of ERC20/ERC721/ERC1155 and native-tokan assets
 *           in a data structure, and provides logic for setting/getting IDs and URIs for created bundles.
 *  @dev     See {ITokenBundle}
 */

abstract contract TokenBundle is ICollateralBundle {
    /// @dev Mapping from bundle UID => bundle info.
    mapping(uint256 => CollateralBundleInfo) private bundle;

    /// @dev The number of bundles that have been created
    uint256 bundleCount ; 

    /// @dev Returns the total number of assets in a particular bundle.
    function getTokenCountOfBundle(uint256 _bundleId)
        public
        view
        returns (uint256)
    {
        return bundle[_bundleId].count;
    }

    /// @dev Returns an asset contained in a particular bundle, at a particular index.
    function getTokenOfBundle(uint256 _bundleId, uint256 index)
        public
        view
        returns (Collateral memory)
    {
        return bundle[_bundleId].collaterals[index];
    }

    /// @dev Returns the struct of a particular bundle.
    /* function getBundleInfo(uint256 _bundleId) public view returns (CollateralBundleInfo memory) {
        return bundle[_bundleId];
    }*/

    /// @dev Lets the calling contract create a bundle, by passing in a list of tokens and a unique id.
    function _createBundle(Collateral[] memory _tokensToBind)
        internal returns (uint256 bundleId_)
    {   
        bundleId_ = bundleCount++;

        uint256 targetCount = _tokensToBind.length;

        require(targetCount > 0, "!Tokens");
        require(bundle[bundleId_].count == 0, "Token bundle id exists");

        for (uint256 i = 0; i < targetCount; i += 1) {
            _checkTokenType(_tokensToBind[i]);
            bundle[bundleId_].collaterals[i] = _tokensToBind[i];
        }

        bundle[bundleId_].count = targetCount;
    }

    /// @dev Lets the calling contract update a bundle, by passing in a list of tokens and a unique id.
    function _updateBundle(Collateral[] memory _tokensToBind, uint256 _bundleId)
        internal
    {
        require(_tokensToBind.length > 0, "!Tokens");

        uint256 currentCount = bundle[_bundleId].count;
        uint256 targetCount = _tokensToBind.length;
        uint256 check = currentCount > targetCount ? currentCount : targetCount;

        for (uint256 i = 0; i < check; i += 1) {
            if (i < targetCount) {
                _checkTokenType(_tokensToBind[i]);
                bundle[_bundleId].collaterals[i] = _tokensToBind[i];
            } else if (i < currentCount) {
                delete bundle[_bundleId].collaterals[i];
            }
        }

        bundle[_bundleId].count = targetCount;
    }

    /// @dev Lets the calling contract add a token to a bundle for a unique bundle id and index.
    function _addTokenInBundle(
        Collateral memory _tokenToBind,
        uint256 _bundleId
    ) internal {
        _checkTokenType(_tokenToBind);
        uint256 id = bundle[_bundleId].count;

        bundle[_bundleId].collaterals[id] = _tokenToBind;
        bundle[_bundleId].count += 1;
    }

    /// @dev Lets the calling contract update a token in a bundle for a unique bundle id and index.
    function _updateTokenInBundle(
        Collateral memory _tokenToBind,
        uint256 _bundleId,
        uint256 _index
    ) internal {
        require(_index < bundle[_bundleId].count, "index DNE");
        _checkTokenType(_tokenToBind);
        bundle[_bundleId].collaterals[_index] = _tokenToBind;
    }

    /// @dev Checks if the type of asset-contract is same as the TokenType specified.
    function _checkTokenType(Collateral memory _token) 
    internal view {
        if (_token._collateralType == CollateralType.ERC721) {
            try
                IERC165(_token._collateralAddress).supportsInterface(0x80ac58cd)
            returns (bool supported721) {
                require(supported721, "TokenBundle: ERC721 Interface Not Supported");
            } catch {
                revert("TokenBundle: ERC721 Interface Not Supported");
            }
        } else if (_token._collateralType == CollateralType.ERC1155) {
            try
                IERC165(_token._collateralAddress).supportsInterface(0xd9b67a26)
            returns (bool supported1155) {
                require(supported1155, "TokenBundle: ERC1155 Interface Not Supported");
            } catch {
                revert("TokenBundle: ERC1155 Interface Not Supported");
            }
        } else if (_token._collateralType == CollateralType.ERC20) {
            if (_token._collateralAddress != CurrencyTransferLib.NATIVE_TOKEN) {
                // 0x36372b07
                try
                    IERC165(_token._collateralAddress).supportsInterface(
                        0x80ac58cd
                    )
                returns (bool supported721) {
                    require(!supported721, "!TokenType");

                    try
                        IERC165(_token._collateralAddress).supportsInterface(
                            0xd9b67a26
                        )
                    returns (bool supported1155) {
                        require(!supported1155, "!TokenType");
                    } catch Error(string memory) {} catch {}
                } catch Error(string memory) {} catch {}
            }
        }
    }

    /// @dev Lets the calling contract set/update the uri of a particular bundle.
    /* function _setUriOfBundle(string memory _uri, uint256 _bundleId) internal {
        bundle[_bundleId].uri = _uri;
    }*/

    /// @dev Lets the calling contract delete a particular bundle.
    function _deleteBundle(uint256 _bundleId) internal {
        for (uint256 i = 0; i < bundle[_bundleId].count; i += 1) {
            delete bundle[_bundleId].collaterals[i];
        }
        bundle[_bundleId].count = 0;
    }
}
