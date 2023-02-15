pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import "./TellerV2MarketForwarder.sol";

import "./interfaces/ICollateralManager.sol";

import {
    Collateral,
    CollateralType
} from "./interfaces/escrow/ICollateralEscrowV1.sol";

/*
consider lender being in its own mapping 

consider borrowers = an array / enumerable set . 


simplify updateCommitment by using struct arg 


*/


contract LenderCommitmentForwarder is TellerV2MarketForwarder {


    enum CommitmentCollateralType {
        ERC20,
        ERC721,
        ERC1155,
        ERC721_ANY_ID, //used only for lender commitments
        ERC1155_ANY_ID //used only for lender commitments
    }

    uint256 public constant PRINCIPAL_PER_COLLATERAL_EXPANSION_FACTOR = 10**16;


    /**
     * @notice Details about a lender's capital commitment.
     * @param maxPrincipal Amount of tokens being committed by the lender. Max amount that can be loaned.
     * @param expiration Expiration time in seconds, when the commitment expires.
     * @param maxDuration Length of time, in seconds that the lender's capital can be lent out for.
     * @param minInterestRate Minimum Annual percentage to be applied for loans using the lender's capital.
     * @param collateralTokenAddress The address for the token contract that must be used to provide collateral for loans for this commitment.
     * @param maxPrincipalPerCollateralAmount The amount of principal that can be used for a loan per each unit of collateral, expanded by 10^8. Use zero for no collateral required.
     * @param collateralTokenType The type of asset of the collateralTokenAddres (ERC20, ERC721, or ERC1155).
     * @param lender The address of the lender for this commitment.
     * @param marketId The market id for this commitment.
     * @param principalTokenAddress The address for the token contract that will be used to provide principal for loans of this commitment.
     * @param borrower The address of the borrower that is allowed to accept this commitment.  Zero address is wildcard for any address. 
     */
    struct Commitment {
        uint256 maxPrincipal;
        uint32 expiration;
        uint32 maxDuration;
        uint16 minInterestRate;
        address collateralTokenAddress;
        uint256 collateralTokenId; 
        uint256 maxPrincipalPerCollateralAmount; //zero means infinite . This is expressed using 16 decimals [PRINCIPAL_PER_COLLATERAL_EXPANSION_FACTOR] so 1 wei is 10^16 and 1 usdc is 10^22 
        CommitmentCollateralType collateralTokenType; //erc721, erc1155 or erc20
        address lender;
        uint256 marketId;
        address principalTokenAddress;
        address borrower;
    }
 
    // Mapping of lender address => market ID => lending token => commitment
    //mapping(address => mapping(uint256 => mapping(address => Commitment))) public __lenderMarketCommitments_deprecated;

    // CommitmentId => commitment
    mapping(uint256 => Commitment) public lenderMarketCommitments;

    uint256 commitmentCount;

    /**
     * @notice This event is emitted when a lender's commitment is created.
     * @param lender The address of the lender.
     * @param marketId The Id of the market the commitment applies to.
     * @param lendingToken The address of the asset being committed.
     * @param tokenAmount The amount of the asset being committed.
     */
    event CreatedCommitment(
        uint256 indexed commitmentId,
        address lender,
        uint256 marketId,
        address lendingToken,
        uint256 tokenAmount

         
    );

    /**
     * @notice This event is emitted when a lender's commitment is updated.
     * @param lender The address of the lender.
     * @param marketId The Id of the market the commitment applies to.
     * @param lendingToken The address of the asset being committed.
     * @param tokenAmount The amount of the asset being committed.
     */
    event UpdatedCommitment(
        uint256 indexed commitmentId,
        address lender,
        uint256 marketId,
        address lendingToken,
        uint256 tokenAmount

       
    );

    /**
     * @notice This event is emitted when a lender's commitment has been deleted.
     * @param commitmentId The id of the commitment that was deleted.
     */
    event DeletedCommitment(uint256 indexed commitmentId);

    /**
     * @notice This event is emitted when a lender's commitment is exercised for a loan.
     * @param borrower The address of the borrower.
     * @param marketId The Id of the market the commitment applies to.
     * @param lendingToken The address of the asset being committed.
     * @param tokenAmount The amount of the asset being committed.
     * @param bidId The bid id for the loan from TellerV2.
     */
    event ExercisedCommitment(
        uint256 indexed commitmentId,
        address borrower,
        uint256 marketId,
        address lendingToken,
        uint256 tokenAmount,
        uint256 indexed bidId

    
    );

    /** External Functions **/

    constructor(address _protocolAddress, address _marketRegistry)
        TellerV2MarketForwarder(_protocolAddress, _marketRegistry)
    {}

  /**
     * @notice Created a loan commitment from a lender to a market.
     * @param _marketId The marketId in which the commitment is valid
     * @param _principalTokenAddress The address of the asset being committed.
     * @param _maxPrincipal Amount of tokens being committed by the lender.

     * @param _collateralTokenAddress The address of the collateral asset required for the loan.
     * @param _maxPrincipalPerCollateralAmount Amount of loan principal allowed per each collateral amount expressed in raw value regardles of token decimals.
     * @param _collateralTokenType The token type of the collateral 

     * @param _maxLoanDuration Length of time, in seconds that the lender's capital can be lent out for.
     * @param _minInterestRate Minimum Annual percentage to be applied for loans using the lender's capital.
     * @param _expiration Expiration time in seconds, when the commitment expires.
     * @param _borrower The address of the borrower who is allowed to accept this commitment.  Use the zero address to wildcard for any borrower.
     */
    function createCommitment(
        uint256 _marketId,
        address _principalTokenAddress,
        uint256 _maxPrincipal,
        address _collateralTokenAddress,
        uint256 _collateralTokenId,
        uint256 _maxPrincipalPerCollateralAmount,
        CommitmentCollateralType _collateralTokenType,
        uint32 _maxLoanDuration,
        uint16 _minInterestRate,
        uint32 _expiration,
        address _borrower
    ) public returns (uint256 commitmentId) {
        commitmentId = commitmentCount++;

        lenderMarketCommitments[commitmentId] = Commitment({
            maxPrincipal: _maxPrincipal,
            expiration: _expiration,
            maxDuration: _maxLoanDuration,
            minInterestRate: _minInterestRate,
            collateralTokenAddress: _collateralTokenAddress,
            collateralTokenId: _collateralTokenId,
            maxPrincipalPerCollateralAmount: _maxPrincipalPerCollateralAmount,
            collateralTokenType: _collateralTokenType,
            lender: _msgSender(),
            marketId: _marketId,
            principalTokenAddress: _principalTokenAddress,
            borrower: _borrower
        });

        emit CreatedCommitment(
            commitmentId,
            _msgSender(),
            _marketId,
            _principalTokenAddress,
            _maxPrincipal
        );
    }

    /**
     * @notice Updates the commitment of a lender to a market.
     * @param _commitmentId The Id of the commitment to update.
     * @param _marketId The marketId in which the commitment is valid
     * @param _principalTokenAddress The address of the asset being committed.
     * @param _maxPrincipal Amount of tokens being committed by the lender.

     * @param _collateralTokenAddress The address of the collateral asset required for the loan.
     * @param _maxPrincipalPerCollateralAmount Amount of loan principal allowed per each collateral amount expressed in raw value regardles of token decimals.
     * @param _collateralTokenType The token type of the collateral 

     * @param _maxLoanDuration Length of time, in seconds that the lender's capital can be lent out for.
     * @param _minInterestRate Minimum Annual percentage to be applied for loans using the lender's capital.
     * @param _expiration Expiration time in seconds, when the commitment expires.
     * @param _borrower The address of the borrower who is allowed to accept this commitment.  Use the zero address to wildcard for any borrower.
     */
    function updateCommitment(
        uint256 _commitmentId,
        uint256 _marketId,
        address _principalTokenAddress,
        uint256 _maxPrincipal,
        address _collateralTokenAddress,
        uint256 _collateralTokenId,
        uint256 _maxPrincipalPerCollateralAmount,
        CommitmentCollateralType _collateralTokenType,
        uint32 _maxLoanDuration,
        uint16 _minInterestRate,
        uint32 _expiration,
        address _borrower
    ) public {
        require(_expiration > uint32(block.timestamp));

        Commitment storage commitment = lenderMarketCommitments[_commitmentId];

        require(
            _msgSender() == commitment.lender,
            "Unauthorized to update commitment"
        );

        commitment.marketId = _marketId;
        commitment.principalTokenAddress = _principalTokenAddress;
        commitment.collateralTokenId = _collateralTokenId;
        commitment.maxPrincipal = _maxPrincipal;
        commitment.collateralTokenAddress = _collateralTokenAddress;
        commitment
            .maxPrincipalPerCollateralAmount = _maxPrincipalPerCollateralAmount;
        commitment.expiration = _expiration;
        commitment.maxDuration = _maxLoanDuration;
        commitment.minInterestRate = _minInterestRate;
        commitment.collateralTokenType = _collateralTokenType;
        commitment.borrower = _borrower;

        emit UpdatedCommitment(
            _commitmentId,
            _msgSender(),
            _marketId,
            _principalTokenAddress,
            _maxPrincipal 
        );
    }

    /**
     * @notice Removes the commitment of a lender to a market.
     * @param _commitmentId The id of the commitment to delete.
   
     */
    function deleteCommitment(uint256 _commitmentId) public {
        require(
            lenderMarketCommitments[_commitmentId].lender == _msgSender(),
            "Unauthorized to delete commitment"
        );

        
        delete lenderMarketCommitments[_commitmentId];
        emit DeletedCommitment(_commitmentId);
    }

     

    /**
     * @notice Reduces the commitment amount for a lender to a market.
     * @param _commitmentId The id of the commitment to modify.
     * @param _tokenAmountDelta The amount of change in the maxPrincipal.
     */
    function _decrementCommitment(
        uint256 _commitmentId,
        uint256 _tokenAmountDelta
    ) internal {
        lenderMarketCommitments[_commitmentId]
            .maxPrincipal -= _tokenAmountDelta;
    }

    /**
     * @notice Accept the commitment to submitBid and acceptBid using the funds

     * @param _commitmentId The id of the commitment being accepted.
    
  
     * @param _principalAmount The amount of currency to borrow for the loan.
     * @param _collateralAmount The amount of collateral to use for the loan.
     * @param _collateralTokenId The tokenId of collateral to use for the loan if ERC721 or ERC1155.
 
     */
    function acceptCommitment(
        uint256 _commitmentId,
       // uint256 _marketId,
        uint256 _principalAmount,
        uint256 _collateralAmount,
        uint256 _collateralTokenId
    ) external returns (uint256 bidId) {
        address borrower = _msgSender();

        Commitment storage commitment = lenderMarketCommitments[_commitmentId];

        require(
            commitment.borrower == address(0) || borrower == commitment.borrower, "Unauthorized borrower for this commitment"
        );

        

        require(
            _principalAmount <= commitment.maxPrincipal,
            "Commitment principal insufficient"
        );
        require(
            _loanDuration <= commitment.maxDuration,
            "Maximum Loan duration exceeded"
        );
        require(
            _interestRate >= commitment.minInterestRate,
            "Interest rate insufficient for commitment"
        );
        require(
            block.timestamp < commitment.expiration,
            "Commitment has expired"
        );

        require(
            commitment.maxPrincipalPerCollateralAmount == 0 || 
                _collateralAmount >= getRequiredCollateral(_principalAmount, commitment.maxPrincipalPerCollateralAmount),

            "Insufficient collateral"
        );

        if(commitment.collateralTokenType == CommitmentCollateralType.ERC721 ||
        commitment.collateralTokenType == CommitmentCollateralType.ERC721_ANY_ID ){
              require( _collateralAmount == 1, "Invalid amount for ERC721");
        }

        if(commitment.collateralTokenType == CommitmentCollateralType.ERC721 ||
        commitment.collateralTokenType == CommitmentCollateralType.ERC1155 ){
              require( commitment.collateralTokenId == _collateralTokenId, "Invalid tokenId");
        }
      

        bidId = _submitBidFromCommitment(
            borrower,
            commitment.marketId,
            commitment.principalTokenAddress,
            _principalAmount,
            commitment.collateralTokenAddress,
            _collateralAmount,
            _collateralTokenId,
            commitment.collateralTokenType,
            _loanDuration,
            _interestRate
        );

        _acceptBid(bidId, commitment.lender);

        _decrementCommitment(_commitmentId, _principalAmount);

        emit ExercisedCommitment(
            _commitmentId,
            borrower,
            commitment.marketId,
            commitment.principalTokenAddress,
            _principalAmount,
            bidId 
        );
    }

    //fix tests
    //use math ceiling (OZ math mul div) -- make sure that 700 / 500 = 1.4 rounds up to 2, requiring a quantity of 2 NFTs 
    function getRequiredCollateral(uint256 _principalAmount, uint256 _maxPrincipalPerCollateralAmount) public view virtual returns (uint256 _collateralAmountRaw) {
        _collateralAmountRaw= (_principalAmount *  PRINCIPAL_PER_COLLATERAL_EXPANSION_FACTOR ) / _maxPrincipalPerCollateralAmount;
    }

    function _submitBidFromCommitment(
        address _borrower,
        uint256 _marketId,
        address _principalTokenAddress,
        uint256 _principalAmount,
        address _collateralTokenAddress,
        uint256 _collateralAmount,
        uint256 _collateralTokenId,
        CommitmentCollateralType _collateralTokenType,
        uint32 _loanDuration,
        uint16 _interestRate
    ) internal returns (uint256 bidId) {
        CreateLoanArgs memory createLoanArgs;
        createLoanArgs.marketId = _marketId;
        createLoanArgs.lendingToken = _principalTokenAddress;
        createLoanArgs.principal = _principalAmount;
        createLoanArgs.duration = _loanDuration;
        createLoanArgs.interestRate = _interestRate;

        Collateral[] memory collateralInfo = new Collateral[](1);

        collateralInfo[0] = Collateral({
            _collateralType: _getEscrowCollateralType(_collateralTokenType),
            _tokenId: _collateralTokenId,
            _amount: _collateralAmount,
            _collateralAddress: _collateralTokenAddress
        });

        bidId = _submitBidWithCollateral(
            createLoanArgs,
            collateralInfo,
            _borrower
        );
    }

    function _getEscrowCollateralType(CommitmentCollateralType _type) internal pure returns (CollateralType){

        if(_type == CommitmentCollateralType.ERC20 ){
            return CollateralType.ERC20;
        }
        if(_type == CommitmentCollateralType.ERC721 || _type == CommitmentCollateralType.ERC721_ANY_ID){
            return CollateralType.ERC721;
        }
        if(_type == CommitmentCollateralType.ERC1155 || _type == CommitmentCollateralType.ERC1155_ANY_ID){
            return CollateralType.ERC1155;
        }

        revert("Unknown Collateral Type");
    }
}
