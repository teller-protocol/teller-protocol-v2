pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

// Contracts
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

// Interfaces
import "./interfaces/ILenderManager.sol";
import "./interfaces/ITellerV2.sol";
import "./interfaces/IMarketRegistry.sol";

import {Base64, Strings,  LenderManagerArt} from "./libraries/LenderManagerArt.sol";

contract LenderManager is
    Initializable,
    OwnableUpgradeable,
    ERC721Upgradeable,
    ILenderManager
{
   // using Strings for uint256;
    IMarketRegistry public immutable marketRegistry;

    constructor(IMarketRegistry _marketRegistry) {
        marketRegistry = _marketRegistry;
    }

    function initialize() external initializer {
        __LenderManager_init();
    }

    function __LenderManager_init() internal onlyInitializing {
        __Ownable_init();
        __ERC721_init("TellerLoan", "TLN");
    }

    /**
     * @notice Registers a new active lender for a loan, minting the nft
     * @param _bidId The id for the loan to set.
     * @param _newLender The address of the new active lender.
     */
    function registerLoan(uint256 _bidId, address _newLender)
        public
        override
        onlyOwner
    {
        _mint(_newLender, _bidId);
    }

    /**
     * @notice Returns the address of the lender that owns a given loan/bid.
     * @param _bidId The id of the bid of which to return the market id
     */
    function _getLoanMarketId(uint256 _bidId) internal view returns (uint256) {
        return ITellerV2(owner()).getLoanMarketId(_bidId);
    }

    /**
     * @notice Returns the verification status of a lender for a market.
     * @param _lender The address of the lender which should be verified by the market
     * @param _bidId The id of the bid of which to return the market id
     */
    function _hasMarketVerification(address _lender, uint256 _bidId)
        internal
        view
        virtual
        returns (bool isVerified_)
    {
        uint256 _marketId = _getLoanMarketId(_bidId);

        (isVerified_, ) = marketRegistry.isVerifiedLender(_marketId, _lender);
    }

    /**  ERC721 Functions **/

    function _beforeTokenTransfer(address, address to, uint256 tokenId, uint256)
        internal
        override
    {
        require(_hasMarketVerification(to, tokenId), "Not approved by market");
    }

    function _baseURI() internal view override returns (string memory) {
        return "data:image/svg+xml;charset=utf-8,";
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        
        
        string memory image_svg_encoded = Base64.encode(bytes( 
            LenderManagerArt.generateSVG(
                tokenId,
                bidId,
                principalAmount,
                principalTokenAddress,
                collateralAmount,
                collateralTokenAddress,
                interestRate,
                duration 
                ) ));
    

       string memory name = "Teller Loan NFT";
       string memory description = "This token represents ownership of a loan.  Repayments of principal and interest will be sent to the owner of this token.  If the loan defaults, the owner of this token will be able to claim the underlying collateral.";



        string memory encoded_svg =   string(
                abi.encodePacked(
                    'data:application/json;base64,',
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                name,
                                '", "description":"',
                                description, 
                                '", "image": "',  //use image_data so its a dynamic svg not cached ?
                                'data:image/svg+xml;base64,',
                                image_svg_encoded,
                                '"}'
                            )
                        )
                    )
                )
            );
        
        return encoded_svg;
    }


}



 