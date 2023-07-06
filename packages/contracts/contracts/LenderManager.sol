pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

// Contracts
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


// Interfaces
import "./interfaces/ILenderManager.sol";
import "./interfaces/ITellerV2.sol";
import "./interfaces/ITellerV2Storage.sol";
import "./interfaces/ICollateralManager.sol";
import "./interfaces/IMarketRegistry.sol";

import {LenderManagerArt} from "./libraries/LenderManagerArt.sol";
import {CollateralType,Collateral} from "./interfaces/escrow/ICollateralEscrowV1.sol";

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
        _safeMint(_newLender, _bidId, "");
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

    struct LoanInformation {

        address principalTokenAddress;
        uint256 principalAmount;
        uint16 interestRate;
        uint32 loanDuration;


    }


    function _getLoanInformation(uint256 tokenId) 
    internal view 
    returns (LoanInformation memory loanInformation_) {

        Bid memory bid = ITellerV2Storage(owner()).bids(tokenId);
        
         loanInformation_ = LoanInformation({
            principalTokenAddress: address(bid.loanDetails.lendingToken),
            principalAmount: bid.loanDetails.principal,
            interestRate: bid.terms.APR,
            loanDuration: bid.loanDetails.loanDuration
        });  
 
    }


    function _getCollateralInformation(uint256 tokenId)
    internal view
    returns (Collateral memory collateral_) {

        address collateralManager = ITellerV2Storage(owner()).collateralManager();

        Collateral[] memory collateralArray = ICollateralManager(collateralManager).getCollateralInfo(tokenId);

        if(collateralArray.length == 0) {
            return Collateral({
                _amount: 0,
                _collateralAddress: address(0),
                _collateralType: CollateralType.ERC20,
                _tokenId: 0

            });
        } 

        return collateralArray[0];
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

    LoanInformation memory loanInformation = _getLoanInformation(tokenId);
 

    Collateral memory collateral = _getCollateralInformation(tokenId);
        
        
        string memory image_svg_encoded = Base64.encode(bytes( 
            LenderManagerArt.generateSVG(
                tokenId, //tokenId == bidId 
                loanInformation.principalAmount,
                loanInformation.principalTokenAddress,
                collateral,
                loanInformation.interestRate,
                loanInformation.loanDuration 
                ) ));
    

       string memory name = "Teller Loan NFT";
       string memory description = "This token represents ownership of a loan.  Repayments of principal and interest will be sent to the owner of this token.  If the loan defaults, the owner of this token will be able to claim the underlying collateral.  Please externally verify the parameter of the loan as this rendering is only a summary.";



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
                                '", "image": "',  
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



 