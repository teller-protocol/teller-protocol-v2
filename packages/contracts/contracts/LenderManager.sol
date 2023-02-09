pragma solidity >=0.8.0 <0.9.0;
// SPDX-Licence-Identifier: MIT

// Contracts
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
 
// Interfaces
import "./interfaces/ILenderManager.sol";
import "./interfaces/ITellerV2.sol";
import "./interfaces/IMarketRegistry.sol";

contract LenderManager is
Initializable,
OwnableUpgradeable,
//ERC2771ContextUpgradeable,
ERC721Upgradeable,
ILenderManager
{
    IMarketRegistry public immutable marketRegistry;

    // Mapping of loans to current active lenders - using erc721 now 
   // mapping(uint256 => address) internal _loanActiveLender;
 

    /** Events **/
    event NewLoanRegistered(address indexed newLender, uint256 bidId);

    constructor( address _marketRegistry)
    //ERC2771ContextUpgradeable(_trustedForwarder)
    {
        marketRegistry = IMarketRegistry(_marketRegistry);
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
    function registerLoan(uint256 _bidId, address _newLender )
    public
    override
    onlyOwner
    { 
        _mint(_newLender,_bidId);

        emit NewLoanRegistered(_newLender, _bidId);
    }

    

    /**
     * @notice Returns the address of the lender that owns a given loan/bid.
     * @param _bidId The id of the bid to return the lender for
     * @return The address of the lender.
     */
    function getActiveLoanLender(uint256 _bidId)
    external
    view
    override
    returns (address)
    {
        return _getActiveLender(_bidId);
    }

    /**
     * @notice Returns the address of the lender that owns a given loan/bid.
     * @param _bidId The id of the bid to return the lender for
     * @return lender_ The address of the lender.
     */
    function _getActiveLender(uint256 _bidId)
    internal
    view
    returns (address lender_)
    {
        if(_exists(_bidId)){
            return ownerOf(_bidId);
        }else{
            //CAUTION: If a loan NFT is burned, this branch of code will be executed
            return ITellerV2(owner()).getLoanLender(_bidId);
        }
       
    }

    /**
     * @notice Returns the address of the lender that owns a given loan/bid.
     * @param _bidId The id of the bid of which to return the market id
     */
    function _getLoanMarketId(uint256 _bidId)
    internal
    view
    returns (uint256)
    { 
        return ITellerV2(owner()).getLoanMarketId(_bidId); 
    }


    /**
     * @notice Returns the verification status of a lender for a market.
     * @param _lender The address of the lender which should be verified by the market
     * @param _bidId The id of the bid of which to return the market id
     */
    function _hasMarketVerification(address _lender, uint256 _bidId) 
    internal
    virtual
    view 
    returns (bool)
    {
        
        uint256 _marketId = _getLoanMarketId(_bidId);

        (bool isVerified, ) = marketRegistry.isVerifiedLender(
            _marketId,
            _lender
        );

        return isVerified;
    }


    /**  ERC721 Functions **/


    function _beforeTokenTransfer(
        address,
        address to,
        uint256 tokenId,
        uint256 
    ) internal override {

        require(_hasMarketVerification(to,tokenId), "Not approved by market");

    } 
  

    function _baseURI() internal view override returns (string memory) {
        return "";
    }

 
}