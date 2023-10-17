// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Contracts
//import "./EAS/TellerAS.sol";
//import "./EAS/TellerASResolver.sol";

//must continue to use this so storage slots are not broken
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

// Interfaces
import "./interfaces/IMarketRegistry.sol";
import "./interfaces/IMarketRegistry_V2.sol";

// Libraries
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { PaymentType } from "./libraries/V2Calculations.sol";

contract MarketRegistry_G2 is
    IMarketRegistry,
    IMarketRegistry_V2,
    Initializable,
    Context 
{
    using EnumerableSet for EnumerableSet.AddressSet;

    /** Constant Variables **/

    uint256 public constant CURRENT_CODE_VERSION = 9;

    /* Storage Variables */

    struct Marketplace {
        address owner;
        string metadataURI;
       
       
        uint16 marketplaceFeePercent;   //DEPRECATED
        bool lenderAttestationRequired;  
        EnumerableSet.AddressSet verifiedLendersForMarket;
        mapping(address => bytes32) _lenderAttestationIds; //DEPRECATED
        uint32 paymentCycleDuration;   //DEPRECATED
        uint32 paymentDefaultDuration; //DEPRECATED
        uint32 bidExpirationTime;  //DEPRECATED
        bool borrowerAttestationRequired; 
        EnumerableSet.AddressSet verifiedBorrowersForMarket;
        mapping(address => bytes32) _borrowerAttestationIds; //DEPRECATED
        address feeRecipient;   //DEPRECATED
        PaymentType paymentType;  //DEPRECATED 
        PaymentCycleType paymentCycleType;  //DEPRECATED 

       
    }


    struct MarketplaceTerms {
        
        uint16 marketplaceFeePercent; // 10000 is 100%
       
        uint32 paymentCycleDuration; // unix time (seconds)
        uint32 paymentDefaultDuration; //unix time
        uint32 bidExpirationTime; //unix time
        
        address feeRecipient;
        PaymentType paymentType;
        PaymentCycleType paymentCycleType;
    }

    bytes32 public __lenderAttestationSchemaId; //DEPRECATED

    mapping(uint256 => Marketplace) internal markets;
    mapping(bytes32 => uint256) internal __uriToId; //DEPRECATED
    uint256 public marketCount;
    bytes32 private _attestingSchemaId;
    bytes32 public borrowerAttestationSchemaId;

    uint256 public version;

    mapping(uint256 => bool) private marketIsClosed;
 

    //uint256 marketTermsCount; //  use a hash here instead of uint256 
    mapping(bytes32 => MarketplaceTerms) public marketTerms; 

    //market id => market terms.  Used when a new bid is created. If this is blank for a market, new bids cant be created for that market. 
    mapping(uint256 => bytes32) public currentMarketTermsForMarket; 



    //TellerAS public tellerAS;  //this took 7 storage slots   
    uint256[7] private __teller_as_gap;

  

    /* Modifiers */

    modifier ownsMarket(uint256 _marketId) {
        require(_getMarketOwner(_marketId) == _msgSender(), "Not the owner");
        _;
    }

  /*  modifier withAttestingSchema(bytes32 schemaId) {
        _attestingSchemaId = schemaId;
        _;
        _attestingSchemaId = bytes32(0);
    }*/

    /* Events */

    event MarketCreated(address indexed owner, uint256 marketId);
    event SetMarketURI(uint256 marketId, string uri);
    event SetPaymentCycleDuration(uint256 marketId, uint32 duration); // DEPRECATED - used for subgraph reference
    event SetPaymentCycle(
        uint256 marketId,
        PaymentCycleType paymentCycleType,
        uint32 value
    );
    event SetPaymentDefaultDuration(uint256 marketId, uint32 duration);
    event SetBidExpirationTime(uint256 marketId, uint32 duration);
    event SetMarketFee(uint256 marketId, uint16 feePct);
    event LenderAttestation(uint256 marketId, address lender);
    event BorrowerAttestation(uint256 marketId, address borrower);
    event LenderRevocation(uint256 marketId, address lender);
    event BorrowerRevocation(uint256 marketId, address borrower);
    event MarketClosed(uint256 marketId);
    event LenderExitMarket(uint256 marketId, address lender);
    event BorrowerExitMarket(uint256 marketId, address borrower);
    event SetMarketOwner(uint256 marketId, address newOwner);
    event SetMarketFeeRecipient(uint256 marketId, address newRecipient);
    event SetMarketLenderAttestation(uint256 marketId, bool required);
    event SetMarketBorrowerAttestation(uint256 marketId, bool required);
    event SetMarketPaymentType(uint256 marketId, PaymentType paymentType);
 
    event DefineMarketTerms(bytes32 marketTermsId );
    event SetCurrentMarketTermsForMarket(uint256 marketId, bytes32 marketTermsId);
  
    /* External Functions */

    function initialize( ) external initializer {
       /* tellerAS = _tellerAS;

        lenderAttestationSchemaId = tellerAS.getASRegistry().register(
            "(uint256 marketId, address lenderAddress)",
            this
        );
        borrowerAttestationSchemaId = tellerAS.getASRegistry().register(
            "(uint256 marketId, address borrowerAddress)",
            this
        ); */
    }

    /**
     * @notice Creates a new market.
     * @param _initialOwner Address who will initially own the market.
     * @param _paymentCycleDuration Length of time in seconds before a bid's next payment is required to be made.
     * @param _paymentDefaultDuration Length of time in seconds before a loan is considered in default for non-payment.
     * @param _bidExpirationTime Length of time in seconds before pending bids expire.
     * @param _requireLenderAttestation Boolean that indicates if lenders require attestation to join market.
     * @param _requireBorrowerAttestation Boolean that indicates if borrowers require attestation to join market.
     * @param _paymentType The payment type for loans in the market.
     * @param _uri URI string to get metadata details about the market.
     * @param _paymentCycleType The payment cycle type for loans in the market - Seconds or Monthly
     * @return marketId_ The market ID of the newly created market.
     */
    function createMarket(
        address _initialOwner,
        uint32 _paymentCycleDuration,
        uint32 _paymentDefaultDuration,
        uint32 _bidExpirationTime,
        uint16 _feePercent,
        bool _requireLenderAttestation,
        bool _requireBorrowerAttestation,
        PaymentType _paymentType,
        PaymentCycleType _paymentCycleType,
        string calldata _uri
    ) external returns (uint256 marketId_) {
        marketId_ = _createMarket(
            _initialOwner,
            _paymentCycleDuration,
            _paymentDefaultDuration,
            _bidExpirationTime,
            _feePercent,
            _requireLenderAttestation,
            _requireBorrowerAttestation,
            _paymentType,
            _paymentCycleType,
            _uri
        );
    }

    /**
     * @notice Creates a new market.
     * @dev Uses the default EMI payment type.
     * @param _initialOwner Address who will initially own the market.
     * @param _paymentCycleDuration Length of time in seconds before a bid's next payment is required to be made.
     * @param _paymentDefaultDuration Length of time in seconds before a loan is considered in default for non-payment.
     * @param _bidExpirationTime Length of time in seconds before pending bids expire.
     * @param _requireLenderAttestation Boolean that indicates if lenders require attestation to join market.
     * @param _requireBorrowerAttestation Boolean that indicates if borrowers require attestation to join market.
     * @param _uri URI string to get metadata details about the market.
     * @return marketId_ The market ID of the newly created market.
     */
    /*function createMarket(
        address _initialOwner,
        uint32 _paymentCycleDuration,
        uint32 _paymentDefaultDuration,
        uint32 _bidExpirationTime,
        uint16 _feePercent,
        bool _requireLenderAttestation,
        bool _requireBorrowerAttestation,
        string calldata _uri
    ) external returns (uint256 marketId_) {
        marketId_ = _createMarket(
            _initialOwner,
            _paymentCycleDuration,
            _paymentDefaultDuration,
            _bidExpirationTime,
            _feePercent,
            _requireLenderAttestation,
            _requireBorrowerAttestation,
            PaymentType.EMI,
            PaymentCycleType.Seconds,
            _uri
        );
    }*/

    /**
     * @notice Creates a new market.
     * @param _initialOwner Address who will initially own the market.
     * @param _paymentCycleDuration Length of time in seconds before a bid's next payment is required to be made.
     * @param _paymentDefaultDuration Length of time in seconds before a loan is considered in default for non-payment.
     * @param _bidExpirationTime Length of time in seconds before pending bids expire.
     * @param _requireLenderAttestation Boolean that indicates if lenders require attestation to join market.
     * @param _requireBorrowerAttestation Boolean that indicates if borrowers require attestation to join market.
     * @param _paymentType The payment type for loans in the market.
     * @param _uri URI string to get metadata details about the market.
     * @param _paymentCycleType The payment cycle type for loans in the market - Seconds or Monthly
     * @return marketId_ The market ID of the newly created market.
     */
    function _createMarket(
        address _initialOwner,
        uint32 _paymentCycleDuration,
        uint32 _paymentDefaultDuration,
        uint32 _bidExpirationTime,
        uint16 _feePercent,
        bool _requireLenderAttestation,
        bool _requireBorrowerAttestation,
        PaymentType _paymentType,
        PaymentCycleType _paymentCycleType,
        string calldata _uri
    ) internal returns (uint256 marketId_) {
        require(_initialOwner != address(0), "Invalid owner address");
        // Increment market ID counter
        marketId_ = ++marketCount;

        // Set the market owner
        markets[marketId_].owner = _initialOwner;
        markets[marketId_].metadataURI = _uri;

        markets[marketId_].borrowerAttestationRequired = _requireBorrowerAttestation;
        markets[marketId_].lenderAttestationRequired = _requireLenderAttestation;
       
        address feeRecipient = _initialOwner; 

        // Initialize market settings
        _updateMarketSettings(
            marketId_,
            _paymentCycleDuration,
            _paymentType,
            _paymentCycleType,
            _paymentDefaultDuration,
            _bidExpirationTime,
            _feePercent,
            
            feeRecipient
        ); 


        emit MarketCreated(_initialOwner, marketId_);
    }

    /**
     * @notice Closes a market so new bids cannot be added.
     * @param _marketId The market ID for the market to close.
     */

    function closeMarket(uint256 _marketId) public ownsMarket(_marketId) {
        if (!marketIsClosed[_marketId]) {
            marketIsClosed[_marketId] = true;

            emit MarketClosed(_marketId);
        }
    }

    /**
     * @notice Returns the status of a market existing and not being closed.
     * @param _marketId The market ID for the market to check.
     */
    function isMarketOpen(uint256 _marketId)
        public
        view
        override
        returns (bool)
    {
        return
            markets[_marketId].owner != address(0) &&
            !marketIsClosed[_marketId];
    }

    /**
     * @notice Returns the status of a market being open or closed for new bids. Does not indicate whether or not a market exists.
     * @param _marketId The market ID for the market to check.
     */
    function isMarketClosed(uint256 _marketId)
        public
        view
        override
        returns (bool)
    {
        return marketIsClosed[_marketId];
    }


    /**
     * @notice Transfers ownership of a marketplace.
     * @param _marketId The ID of a market.
     * @param _newOwner Address of the new market owner.
     *
     * Requirements:
     * - The caller must be the current owner.
     */
    function transferMarketOwnership(uint256 _marketId, address _newOwner)
        public
        ownsMarket(_marketId)
    {
        markets[_marketId].owner = _newOwner;
        emit SetMarketOwner(_marketId, _newOwner);
    }

    /**
     * @notice Updates multiple market settings for a given market.
     * @param _marketId The ID of a market.
     * @param _paymentCycleDuration Delinquency duration for new loans
     * @param _newPaymentType The payment type for the market.
     * @param _paymentCycleType The payment cycle type for loans in the market - Seconds or Monthly
     * @param _paymentDefaultDuration Default duration for new loans
     * @param _bidExpirationTime Duration of time before a bid is considered out of date 
     *
     * Requirements:
     * - The caller must be the current owner.
     */
    function updateMarketSettings(
        uint256 _marketId,
        uint32 _paymentCycleDuration,
        PaymentType _newPaymentType,
        PaymentCycleType _paymentCycleType,
        uint32 _paymentDefaultDuration,
        uint32 _bidExpirationTime,
        uint16 _feePercent,
      
        address _feeRecipient
    ) public ownsMarket(_marketId) {

 

        _updateMarketSettings( 
            _marketId, 
            _paymentCycleDuration,
            _newPaymentType,
            _paymentCycleType,
            _paymentDefaultDuration,
            _bidExpirationTime,
            _feePercent,
           
            _feeRecipient
         );
      
       
       
    }

       function _updateMarketSettings(
        uint256 _marketId,
        uint32 _paymentCycleDuration,
        PaymentType _newPaymentType,
        PaymentCycleType _paymentCycleType,
        uint32 _paymentDefaultDuration,
        uint32 _bidExpirationTime,
        uint16 _feePercent,
        
        address _feeRecipient
    ) internal returns (bytes32 marketTermsId_ ) {

 

        marketTermsId_ = _defineNewMarketTermsRevision( 
           
            _paymentCycleDuration,
            _newPaymentType,
            _paymentCycleType,
            _paymentDefaultDuration,
            _bidExpirationTime,
            _feePercent,
        
            _feeRecipient
         );
        emit DefineMarketTerms( marketTermsId_  );

        currentMarketTermsForMarket[_marketId] = marketTermsId_;
        emit SetCurrentMarketTermsForMarket(_marketId, marketTermsId_);
       
       
    }


    function marketHasDefinedTerms(uint256 _marketId) public view returns (bool) { 
        return currentMarketTermsForMarket[_marketId] != bytes32(0); 
    }

    function getCurrentTermsForMarket(uint256 _marketId) public view returns (bytes32) {
        return currentMarketTermsForMarket[_marketId];
    }
 
 
    /**
     * @notice Sets the metadata URI for a market.
     * @param _marketId The ID of a market.
     * @param _uri A URI that points to a market's metadata.
     *
     * Requirements:
     * - The caller must be the current owner.
     */
    function setMarketURI(uint256 _marketId, string calldata _uri)
        public
        ownsMarket(_marketId)
    {
        //We do string comparison by checking the hashes of the strings against one another
        if (
            keccak256(abi.encodePacked(_uri)) !=
            keccak256(abi.encodePacked(markets[_marketId].metadataURI))
        ) {
            markets[_marketId].metadataURI = _uri;

            emit SetMarketURI(_marketId, _uri);
        }
    }
   

      
        //need to rebuild this 
    /**
     * @notice Gets the data associated with a market.
     * @param _marketId The ID of a market.
     */
    function getMarketData(uint256 _marketId)
        public
        view
        returns (
            address owner, 
            string memory metadataURI, 
            bool borrowerAttestationRequired,
            bool lenderAttestationRequired,
            bytes32 marketTermsId
        )
    {
        return (
            markets[_marketId].owner,
            markets[_marketId].metadataURI,
            markets[_marketId].borrowerAttestationRequired,
            markets[_marketId].lenderAttestationRequired,
            currentMarketTermsForMarket[_marketId]
        );
    }
 

     function getMarketTermsData(bytes32 _marketTermsId)
        public
        view
        returns (
             
            uint32 paymentCycleDuration,
            PaymentType paymentType,
            PaymentCycleType paymentCycleType,
            uint32 paymentDefaultDuration,
            uint32 bidExpirationTime ,
            uint16 feePercent,
            address feeRecipient 

        )
    {
        return (
           
            marketTerms[_marketTermsId].paymentCycleDuration,
            marketTerms[_marketTermsId].paymentType,
            marketTerms[_marketTermsId].paymentCycleType,
              
            marketTerms[_marketTermsId].paymentDefaultDuration,
            marketTerms[_marketTermsId].bidExpirationTime,
            marketTerms[_marketTermsId].marketplaceFeePercent,
            marketTerms[_marketTermsId].feeRecipient 
            
        );
    }



    /**
     * @notice Gets the attestation requirements for a given market.
     * @param _marketId The ID of the market.
     */
    function getMarketAttestationRequirements(uint256 _marketId)
        public
        view
        returns (
            bool lenderAttestationRequired,
            bool borrowerAttestationRequired
        )
    {
        
        return (
            markets[_marketId].lenderAttestationRequired,
            markets[_marketId].borrowerAttestationRequired
        );
    }

    /**
     * @notice Gets the address of a market's owner.
     * @param _marketId The ID of a market.
     * @return The address of a market's owner.
     */
    function getMarketOwner(uint256 _marketId)
        public
        view
        virtual
        override
        returns (address)
    {
        return _getMarketOwner(_marketId);
    }

    /**
     * @notice Gets the address of a market's owner.
     * @param _marketId The ID of a market.
     * @return The address of a market's owner.
     */
    function _getMarketOwner(uint256 _marketId)
        internal
        view
        virtual
        returns (address)
    {
        return markets[_marketId].owner;
    }

    
    /**
     * @notice Gets the metadata URI of a market.
     * @param _marketId The ID of a market.
     * @return URI of a market's metadata.
     */
    function getMarketURI(uint256 _marketId)
        public
        view
        override
        returns (string memory)
    {
        return markets[_marketId].metadataURI;
    }

     
     /**
     * @notice Gets the current marketplace fee of a market. This is a carryover to support legacy contracts
     * @param _marketId The ID of a market.
     * @return URI of a market's metadata.
     */
    function getMarketplaceFee(uint256 _marketId)
        external
        view
        returns (uint16)
    {
        uint256 _marketTermsId = currentMarketTermsForMarket[_marketId];
        return marketTerms[_marketTermsId].marketFee ; 
    
    }




    function getMarketplaceFeeTerms(bytes32 _marketTermsId) public
        view
        
        returns ( address , uint16 )
    {

        return (
            marketTerms[_marketTermsId].marketFeeRecipient,
            marketTerms[_marketTermsId].marketFee
        );

    }

    function getMarketTermsForLending(bytes32 _marketTermsId)
        public
        view
        
        returns ( uint32, PaymentCycleType, PaymentType, uint32, uint32 )
    {
        require(_marketTermsId != bytes32(0), "Invalid market terms." );
 

        return (
            marketTerms[_marketTermsId].paymentCycleDuration,
            marketTerms[_marketTermsId].paymentCycleType,
            marketTerms[_marketTermsId].paymentType,
            marketTerms[_marketTermsId].paymentDefaultDuration,
            marketTerms[_marketTermsId].bidExpirationTime
        );
    }

 

    /**
     * @notice Gets the loan default duration of a market.
     * @param _marketTermsId The ID of the market terms.
     * @return Duration of a loan repayment interval until it is default.
     */
    function getPaymentDefaultDuration(bytes32 _marketTermsId)
        public
        view
        
        returns (uint32)
    {
        return marketTerms[_marketTermsId].bidExpirationTime;
    }

    /**
     * @notice Get the payment type of a market.
     * @param _marketTermsId the ID of the market terms.
     * @return The type of payment for loans in the market.
     */
    function getPaymentType(bytes32 _marketTermsId)
        public
        view
        //override
        returns (PaymentType)
    {
         return marketTerms[_marketTermsId].bidExpirationTime;
    }

    /**
     * @notice Gets the loan default duration of a market.
     * @param _marketTermsId The ID of the market terms.
     * @return Expiration of a loan bid submission until it is no longer acceptable.
     */
    function getBidExpirationTime(bytes32 _marketTermsId)
        public
        view
        //override
        returns (uint32)
    {
        return marketTerms[_marketTermsId].bidExpirationTime;
    }
 





    /**
     * @notice Checks if a lender has been attested and added to a market.
     * @param _marketId The ID of a market.
     * @param _lender Address to check.
     * @return isVerified_ Boolean indicating if a lender has been added to a market.
     
     */
    function isVerifiedLender(uint256 _marketId, address _lender)
        public
        view
        override
        returns (
            bool isVerified_
          //  , bytes32 uuid_
            )
    {
        return
            _isVerified(
                _lender,
                markets[_marketId].lenderAttestationRequired,
                //markets[_marketId].lenderAttestationIds,
                markets[_marketId].verifiedLendersForMarket
            );
    }

    /**
     * @notice Checks if a borrower has been attested and added to a market.
     * @param _marketId The ID of a market.
     * @param _borrower Address of the borrower to check.
     * @return isVerified_ Boolean indicating if a borrower has been added to a market.
     
     */
    function isVerifiedBorrower(uint256 _marketId, address _borrower)
        public
        view
        override
        returns (
            bool isVerified_
           // , bytes32 uuid_
            )
    {
        return
            _isVerified(
                _borrower,
                markets[_marketId].borrowerAttestationRequired,
                //markets[_marketId].borrowerAttestationIds,
                markets[_marketId].verifiedBorrowersForMarket
            );
    }

    /**
     * @notice Gets addresses of all attested lenders.
     * @param _marketId The ID of a market.
     * @param _page Page index to start from.
     * @param _perPage Number of items in a page to return.
     * @return Array of addresses that have been added to a market.
     */
    function getAllVerifiedLendersForMarket(
        uint256 _marketId,
        uint256 _page,
        uint256 _perPage
    ) public view returns (address[] memory) {
        EnumerableSet.AddressSet storage set = markets[_marketId]
            .verifiedLendersForMarket;

        return _getStakeholdersForMarket(set, _page, _perPage);
    }

    /**
     * @notice Gets addresses of all attested borrowers.
     * @param _marketId The ID of the market.
     * @param _page Page index to start from.
     * @param _perPage Number of items in a page to return.
     * @return Array of addresses that have been added to a market.
     */
    function getAllVerifiedBorrowersForMarket(
        uint256 _marketId,
        uint256 _page,
        uint256 _perPage
    ) public view returns (address[] memory) {
        EnumerableSet.AddressSet storage set = markets[_marketId]
            .verifiedBorrowersForMarket;
        return _getStakeholdersForMarket(set, _page, _perPage);
    }

    
   /* function _setMarketSettings(
        uint256 _marketId,
        uint32 _paymentCycleDuration,
        PaymentType _newPaymentType,
        PaymentCycleType _paymentCycleType,
        uint32 _paymentDefaultDuration,
        uint32 _bidExpirationTime,
        uint16 _feePercent,
        bool _borrowerAttestationRequired,
        bool _lenderAttestationRequired,
        string calldata _metadataURI
    ) internal {
        setMarketURI(_marketId, _metadataURI);
        setPaymentDefaultDuration(_marketId, _paymentDefaultDuration);
        setBidExpirationTime(_marketId, _bidExpirationTime);
        setMarketFeePercent(_marketId, _feePercent);
        setLenderAttestationRequired(_marketId, _lenderAttestationRequired);
        setBorrowerAttestationRequired(_marketId, _borrowerAttestationRequired);
        setMarketPaymentType(_marketId, _newPaymentType);
        setPaymentCycle(_marketId, _paymentCycleType, _paymentCycleDuration);
    }*/

    function _defineNewMarketTermsRevision(
        
        uint32 _paymentCycleDuration,
        PaymentType _newPaymentType,
        PaymentCycleType _paymentCycleType,
        uint32 _paymentDefaultDuration,
        uint32 _bidExpirationTime,
        uint16 _feePercent,
       
        address _feeRecipient
     

    ) internal returns (bytes32)  {

        bytes32 marketTermsId = _getMarketTermsHashId ( 
            _paymentCycleDuration,
            _newPaymentType,
            _paymentCycleType,
            _paymentDefaultDuration,
            _bidExpirationTime,
            _feePercent,
             
            _feeRecipient 
        );

      
        marketTerms[marketTermsId] = MarketplaceTerms({
            paymentCycleDuration: _paymentCycleDuration,
            paymentType: _newPaymentType,
            paymentCycleType: _paymentCycleType,
            paymentDefaultDuration: _paymentDefaultDuration,
            bidExpirationTime: _bidExpirationTime,
            marketplaceFeePercent: _feePercent, 
          
            feeRecipient: _feeRecipient
        });

        return marketTermsId;
    }


    function _getMarketTermsHashId( 
        uint32 _paymentCycleDuration,
        PaymentType _newPaymentType,
        PaymentCycleType _paymentCycleType,
        uint32 _paymentDefaultDuration,
        uint32 _bidExpirationTime,
        uint16 _feePercent,
      
        address _feeRecipient

    ) public view returns (bytes32) {

         return keccak256(abi.encode(
            _paymentCycleDuration,
            _newPaymentType,
            _paymentCycleType,
            _paymentDefaultDuration,
            _bidExpirationTime,
            _feePercent,
           
            _feeRecipient
        )); 
    }


    //Attestation Functions 


    /**
     * @notice Adds a lender to a market.
     * @dev See {_attestStakeholder}.
     */
    function attestLender(
        uint256 _marketId,
        address _lenderAddress,
        uint256 _expirationTime
    ) external {
        _attestStakeholder(_marketId, _lenderAddress, _expirationTime, true);
    }

   

    /**
     * @notice Removes a lender from an market.
     * @dev See {_revokeStakeholder}.
     */
    function revokeLender(uint256 _marketId, address _lenderAddress) external {
        _revokeStakeholder(_marketId, _lenderAddress, true);
    }
 

    /**
     * @notice Allows a lender to voluntarily leave a market.
     * @param _marketId The market ID to leave.
     */
    function lenderExitMarket(uint256 _marketId) external {
        // Remove lender address from market set
        bool response = markets[_marketId].verifiedLendersForMarket.remove(
            _msgSender()
        );
        if (response) {
            emit LenderExitMarket(_marketId, _msgSender());
        }
    }

    /**
     * @notice Adds a borrower to a market.
     * @dev See {_attestStakeholder}.
     */
    function attestBorrower(
        uint256 _marketId,
        address _borrowerAddress,
        uint256 _expirationTime
    ) external {
        _attestStakeholder(_marketId, _borrowerAddress, _expirationTime, false);
    }
 

    /**
     * @notice Removes a borrower from an market.
     * @dev See {_revokeStakeholder}.
     */
    function revokeBorrower(uint256 _marketId, address _borrowerAddress)
        external
    {
        _revokeStakeholder(_marketId, _borrowerAddress, false);
    }
 
    /**
     * @notice Allows a borrower to voluntarily leave a market.
     * @param _marketId The market ID to leave.
     */
    function borrowerExitMarket(uint256 _marketId) external {
        // Remove borrower address from market set
        bool response = markets[_marketId].verifiedBorrowersForMarket.remove(
            _msgSender()
        );
        if (response) {
            emit BorrowerExitMarket(_marketId, _msgSender());
        }
    }

    /**
     * @notice Verifies an attestation is valid.
     * @dev This function must only be called by the `attestLender` function above.
     * @param recipient Lender's address who is being attested.
     * @param schema The schema used for the attestation.
     * @param data Data the must include the market ID and lender's address
     * @param
     * @param attestor Market owner's address who signed the attestation.
     * @return Boolean indicating the attestation was successful.
     */
  /*  function resolve(
        address recipient,
        bytes calldata schema,
        bytes calldata data,
        uint256 , // uint256  expirationTime  ,
        address attestor
    ) external payable override returns (bool) {
        bytes32 attestationSchemaId = keccak256(
            abi.encodePacked(schema, address(this))
        );
        (uint256 marketId, address lenderAddress) = abi.decode(
            data,
            (uint256, address)
        );
        return
            (_attestingSchemaId == attestationSchemaId &&
                recipient == lenderAddress &&
                attestor == _getMarketOwner(marketId)) ||
            attestor == address(this);
    }*/



    /**
     * @notice Gets addresses of all attested relevant stakeholders.
     * @param _set The stored set of stakeholders to index from.
     * @param _page Page index to start from.
     * @param _perPage Number of items in a page to return.
     * @return stakeholders_ Array of addresses that have been added to a market.
     */
    function _getStakeholdersForMarket(
        EnumerableSet.AddressSet storage _set,
        uint256 _page,
        uint256 _perPage
    ) internal view returns (address[] memory stakeholders_) {
        uint256 len = _set.length();

        uint256 start = _page * _perPage;
        if (start <= len) {
            uint256 end = start + _perPage;
            // Ensure we do not go out of bounds
            if (end > len) {
                end = len;
            }

            stakeholders_ = new address[](end - start);
            for (uint256 i = start; i < end; i++) {
                stakeholders_[i] = _set.at(i);
            }
        }
    }

    /* Internal Functions */

    /**
     * @notice Adds a stakeholder (lender or borrower) to a market.
     * @param _marketId The market ID to add a borrower to.
     * @param _stakeholderAddress The address of the stakeholder to add to the market.
     * @param _expirationTime The expiration time of the attestation.
     * @param _expirationTime The expiration time of the attestation.
     * @param _isLender Boolean indicating if the stakeholder is a lender. Otherwise it is a borrower.
     */
   function _attestStakeholder(
        uint256 _marketId,
        address _stakeholderAddress,
        uint256 _expirationTime,
        bool _isLender
    )
        internal
        virtual
       /* withAttestingSchema(
            _isLender ? lenderAttestationSchemaId : borrowerAttestationSchemaId
        )*/
    {
        require(
            _msgSender() == _getMarketOwner(_marketId),
            "Not the market owner"
        );

        // Submit attestation for borrower to join a market
      /*  bytes32 uuid = tellerAS.attest(
            _stakeholderAddress,
            _attestingSchemaId, // set by the modifier
            _expirationTime,
            0,
            abi.encode(_marketId, _stakeholderAddress)
        );*/
        _attestStakeholderVerification(
            _marketId,
            _stakeholderAddress,
           // uuid,
            _isLender
        );
    } 
 
  /*  function _attestStakeholderViaDelegation(
        uint256 _marketId,
        address _stakeholderAddress,
        uint256 _expirationTime,
        bool _isLender,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        internal
        virtual
        withAttestingSchema(
            _isLender ? lenderAttestationSchemaId : borrowerAttestationSchemaId
        )
    {
        // NOTE: block scope to prevent stack too deep!
        bytes32 uuid;
        {
            bytes memory data = abi.encode(_marketId, _stakeholderAddress);
            address attestor = _getMarketOwner(_marketId);
            // Submit attestation for stakeholder to join a market (attestation must be signed by market owner)
            uuid = tellerAS.attestByDelegation(
                _stakeholderAddress,
                _attestingSchemaId, // set by the modifier
                _expirationTime,
                0,
                data,
                attestor,
                _v,
                _r,
                _s
            );
        }
        _attestStakeholderVerification(
            _marketId,
            _stakeholderAddress,
            uuid,
            _isLender
        );
    }*/

    /**
     * @notice Adds a stakeholder (borrower/lender) to a market.
     * @param _marketId The market ID to add a stakeholder to.
     * @param _stakeholderAddress The address of the stakeholder to add to the market.
    
     * @param _isLender Boolean indicating if the stakeholder is a lender. Otherwise it is a borrower.
     */
    function _attestStakeholderVerification(
        uint256 _marketId,
        address _stakeholderAddress,
      //  bytes32 _uuid,
        bool _isLender
    ) internal virtual {
        if (_isLender) {
            // Store the lender attestation ID for the market ID
           /* markets[_marketId].lenderAttestationIds[
                _stakeholderAddress
            ] = _uuid;*/
            // Add lender address to market set
            markets[_marketId].verifiedLendersForMarket.add(
                _stakeholderAddress
            );

            emit LenderAttestation(_marketId, _stakeholderAddress);
        } else {
            // Store the lender attestation ID for the market ID
         /*   markets[_marketId].borrowerAttestationIds[
                _stakeholderAddress
            ] = _uuid;*/
            // Add lender address to market set
            markets[_marketId].verifiedBorrowersForMarket.add(
                _stakeholderAddress
            );

            emit BorrowerAttestation(_marketId, _stakeholderAddress);
        }
    }

    /**
     * @notice Removes a stakeholder from an market.
     * @dev The caller must be the market owner.
     * @param _marketId The market ID to remove the borrower from.
     * @param _stakeholderAddress The address of the borrower to remove from the market.
     * @param _isLender Boolean indicating if the stakeholder is a lender. Otherwise it is a borrower.
     */
    function _revokeStakeholder(
        uint256 _marketId,
        address _stakeholderAddress,
        bool _isLender
    ) internal virtual {
        require(
            _msgSender() == _getMarketOwner(_marketId),
            "Not the market owner"
        );

        bytes32 uuid = _revokeStakeholderVerification(
            _marketId,
            _stakeholderAddress,
            _isLender
        );
        // NOTE: Disabling the call to revoke the attestation on EAS contracts
        //        tellerAS.revoke(uuid);
    }

    /**
     * @notice Removes a stakeholder from an market via delegated revocation.
     * @param _marketId The market ID to remove the borrower from.
     * @param _stakeholderAddress The address of the borrower to remove from the market.
     * @param _isLender Boolean indicating if the stakeholder is a lender. Otherwise it is a borrower.
     * @param _v Signature value
     * @param _r Signature value
     * @param _s Signature value
     */
   /* function _revokeStakeholderViaDelegation(
        uint256 _marketId,
        address _stakeholderAddress,
        bool _isLender,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal {
        bytes32 uuid = _revokeStakeholderVerification(
            _marketId,
            _stakeholderAddress,
            _isLender
        );
        // NOTE: Disabling the call to revoke the attestation on EAS contracts
        //        address attestor = markets[_marketId].owner;
        //        tellerAS.revokeByDelegation(uuid, attestor, _v, _r, _s);
    }*/

    /**
     * @notice Removes a stakeholder (borrower/lender) from a market.
     * @param _marketId The market ID to remove the lender from.
     * @param _stakeholderAddress The address of the stakeholder to remove from the market.
     * @param _isLender Boolean indicating if the stakeholder is a lender. Otherwise it is a borrower.
     * @return uuid_ The ID of the previously verified attestation.
     */
    function _revokeStakeholderVerification(
        uint256 _marketId,
        address _stakeholderAddress,
        bool _isLender
    ) internal virtual returns (bytes32 uuid_) {
        if (_isLender) {
            uuid_ = markets[_marketId].lenderAttestationIds[
                _stakeholderAddress
            ];
            // Remove lender address from market set
            markets[_marketId].verifiedLendersForMarket.remove(
                _stakeholderAddress
            );

            emit LenderRevocation(_marketId, _stakeholderAddress);
        } else {
            uuid_ = markets[_marketId].borrowerAttestationIds[
                _stakeholderAddress
            ];
            // Remove borrower address from market set
            markets[_marketId].verifiedBorrowersForMarket.remove(
                _stakeholderAddress
            );

            emit BorrowerRevocation(_marketId, _stakeholderAddress);
        }
    }

    /**
     * @notice Checks if a stakeholder has been attested and added to a market.
     * @param _stakeholderAddress Address of the stakeholder to check.
     * @param _attestationRequired Stored boolean indicating if attestation is required for the stakeholder class.
     
     */
    function _isVerified(
        address _stakeholderAddress,
        bool _attestationRequired,
        //mapping(address => bytes32) storage _stakeholderAttestationIds,
        EnumerableSet.AddressSet storage _verifiedStakeholderForMarket
    ) internal view virtual returns ( bool isVerified_ ) {
        if (_attestationRequired) {
            isVerified_ =
                _verifiedStakeholderForMarket.contains(_stakeholderAddress); /*&&
                tellerAS.isAttestationActive(
                    _stakeholderAttestationIds[_stakeholderAddress]
                );*/
           // uuid_ = _stakeholderAttestationIds[_stakeholderAddress];
        } else {
            isVerified_ = true;
        }
    }
}
