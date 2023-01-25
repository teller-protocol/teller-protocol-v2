pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import "./TellerV2MarketForwarder.sol";

import "./interfaces/ICollateralManager.sol";

import {
    Collateral,
    CollateralType
} from "./interfaces/escrow/ICollateralEscrowV1.sol";

contract LenderCommitmentForwarder is TellerV2MarketForwarder {
    /**
     * @notice Details about a lender's capital commitment.
     * @param amount Amount of tokens being committed by the lender.
     * @param expiration Expiration time in seconds, when the commitment expires.
     * @param maxDuration Length of time, in seconds that the lender's capital can be lent out for.
     * @param minAPR Minimum Annual percentage to be applied for loans using the lender's capital.
     */
    struct Commitment {
        uint256 maxPrincipal;  
        uint32 expiration;
        uint32 maxDuration;
        uint16 minInterestRate;
        address collateralTokenAddress;  
        uint256 maxPrincipalPerCollateralAmount; //zero means infinite 
        CollateralType collateralTokenType; //erc721, erc1155 or erc20
        address lender;
        uint256 marketId;
        address principalTokenAddress;
    }

    modifier onlyMarketOwner(uint256 marketId) {
        require(_msgSender() == getTellerV2MarketOwner(marketId));
        _;
    }

    // Mapping of lender address => market ID => lending token => commitment
    mapping(address => mapping(uint256 => mapping(address => Commitment)))
        public __lenderMarketCommitments_deprecated;

    // CommitmentId => commitment
    mapping(uint256 => Commitment) public lenderMarketCommitments;

    /**
     * @notice This event is emitted when a lender's commitment is submitted.
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
     * @notice This event is emitted when a lender's commitment has been removed.
     * @param lender The address of the lender.
     * @param marketId The Id of the market the commitment removal applies to.
     * @param lendingToken The address of the asset the commitment removal applies to.
     */
    event DeletedCommitment(
        uint256 indexed commitmentId,
        address lender,
        uint256 marketId,
        address lendingToken
    );

    /**
     * @notice This event is emitted when a lender's commitment is exercised for a loan.
     * @param lender The address of the lender.
     * @param marketId The Id of the market the commitment applies to.
     * @param lendingToken The address of the asset being committed.
     * @param tokenAmount The amount of the asset being committed.
     * @param bidId The bid id for the loan from TellerV2.
     */
    event ExercisedCommitment(
        uint256 indexed commitmentId,
        address lender,
        uint256 marketId,
        address lendingToken,
        uint256 tokenAmount,
        uint256 bidId
    );

    /** External Functions **/

    constructor(address _protocolAddress, address _marketRegistry)
        TellerV2MarketForwarder(_protocolAddress, _marketRegistry)
    {}

    /**
     * @notice Updates the commitment of a lender to a market.
     * @param _marketId The Id of the market the commitment applies to.
     * @param _principalTokenAddress The address of the asset being committed.
     * @param _maxPrincipal Amount of tokens being committed by the lender.

     * @param _collateralTokenAddress The address of the collateral asset required for the loan.
     * @param _maxPrincipalPerCollateralAmount Amount of loan principal allowed per each collateral amount expressed in raw value regardles of token decimals.
     * @param _collateralTokenType The token type of the collateral 

     * @param _maxLoanDuration Length of time, in seconds that the lender's capital can be lent out for.
     * @param _minInterestRate Minimum Annual percentage to be applied for loans using the lender's capital.
     * @param _expiration Expiration time in seconds, when the commitment expires.
     */
    function updateCommitment(
        uint256 _commitmentId,
        //uint256 _marketId,
        //address _principalTokenAddress,
        uint256 _maxPrincipal,
        address _collateralTokenAddress,
        uint256 _maxPrincipalPerCollateralAmount,
        CollateralType _collateralTokenType,
        uint32 _maxLoanDuration,
        uint16 _minInterestRate,
        uint32 _expiration
    ) public {
        address lender = _msgSender();
        require(_expiration > uint32(block.timestamp));

        Commitment storage commitment = lenderMarketCommitments[_commitmentId];
        commitment.maxPrincipal = _maxPrincipal;
        commitment.collateralTokenAddress = _collateralTokenAddress;
        commitment
            .maxPrincipalPerCollateralAmount = _maxPrincipalPerCollateralAmount;
        commitment.expiration = _expiration;
        commitment.maxDuration = _maxLoanDuration;
        commitment.minInterestRate = _minInterestRate;
        commitment.collateralTokenType = _collateralTokenType;

        emit UpdatedCommitment(
            _commitmentId,
            lender,
            _marketId,
            _principalTokenAddress,
            _maxPrincipal
        );
    }

    /**
     * @notice Removes the commitment of a lender to a market.
     * @param _marketId The Id of the market the commitment removal applies to.
     * @param _principalTokenAddress The address of the asset for which the commitment is being removed.
     */
    function deleteCommitment(uint256 _commitmentId)
        public
    {
        _deleteCommitment(_msgSender(), _commitmentId);
    }

    /**
     * @notice Removes the commitment of a lender to a market.
     * @param _lender The address of the lender of the commitment.
     * @param _marketId The Id of the market the commitment removal applies to.
     * @param _principalTokenAddress The address of the asset for which the commitment is being removed.
     */
    function _deleteCommitment(
        address _lender, 
        address _commitmentId
    ) internal {

        require(lenderMarketCommitments[_commitmentId].maxPrincipal > 0, "Commitment with zero max principal cannot be deleted.");
        require(lenderMarketCommitments[_commitmentId].lender == _lender, "Unauthorized to delete commitment");
    
        delete lenderMarketCommitments[_commitmentId];
        emit DeletedCommitment(_lender, _commitmentId);
        
    }

    /**
     * @notice Reduces the commitment amount for a lender to a market.
     * @param _lender The address of the lender of the commitment.
     * @param _marketId The Id of the market the commitment removal applies to.
     * @param _principalTokenAddress The address of the asset for which the commitment is being removed.
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
     * @param _marketId The Id of the market the commitment removal applies to.
     * @param _lender The address of the lender of the commitment.
     * @param _principalTokenAddress The address of the asset for which the commitment is being removed.
     * @param _principalAmount The amount of currency to borrow for the loan.
     * @param _loanDuration The loan duration for the TellerV2 loan.
     * @param _interestRate The interest rate for the TellerV2 loan.
     */
    function acceptCommitment(
        uint256 _commitmentId,
        uint256 _marketId,
        address _lender,
        address _principalTokenAddress,
        uint256 _principalAmount,
        uint256 _collateralAmount,
        uint256 _collateralTokenId,
        uint32 _loanDuration,
        uint16 _interestRate
    ) external onlyMarketOwner(_marketId) returns (uint256 bidId) {
        address borrower = _msgSender();

        Commitment storage commitment = lenderMarketCommitments[_commitmentId];

        require(
            _principalAmount <= commitment.maxPrincipal,
            "Commitment principal insufficient"
        );
        require(
            _loanDuration <= commitment.maxDuration,
            "Commitment duration insufficient"
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
                _collateralAmount *
                    (commitment.maxPrincipalPerCollateralAmount) >=
                _principalAmount,
            "Insufficient collateral"
        );

        CreateLoanArgs memory createLoanArgs;
        createLoanArgs.marketId = _marketId;
        createLoanArgs.lendingToken = _principalTokenAddress;
        createLoanArgs.principal = _principalAmount;
        createLoanArgs.duration = _loanDuration;
        createLoanArgs.interestRate = _interestRate;

        Collateral[] memory collateralInfo = new Collateral[](1);

        collateralInfo[0] = Collateral({
            _collateralType: commitment.collateralTokenType,
            _tokenId: _collateralTokenId,
            _amount: _collateralAmount,
            _collateralAddress: commitment.collateralTokenAddress
        });

        bidId = _submitBidWithCollateral(
            createLoanArgs,
            collateralInfo,
            borrower
        ); //(createLoanArgs, borrower);

        _acceptBid(bidId, _lender);

        _decrementCommitment(
            _commitmentId,
            _principalAmount
        );

        emit ExercisedCommitment(
            _commitmentId,
            _lender,
            _marketId,
            _principalTokenAddress,
            _principalAmount,
            bidId
        );
    }

    
}
