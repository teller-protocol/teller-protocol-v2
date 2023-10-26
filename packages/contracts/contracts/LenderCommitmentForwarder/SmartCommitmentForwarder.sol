// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import "../TellerV2MarketForwarder_G2.sol";

import "../interfaces/ILenderCommitmentForwarder.sol";
import "./LenderCommitmentForwarder_G1.sol";

import {CommitmentCollateralType, ISmartCommitment } from "../interfaces/ISmartCommitment.sol";
/*

Borrower approves this contract as being able to create loans on THEIR Behalf.

via  
_submitBidWithCollateral
and _acceptBid 


*/



contract SmartCommitmentForwarder is    
    TellerV2MarketForwarder_G2
{ 

    event ExercisedSmartCommitment(
        address indexed smartCommitmentAddress,
        address borrower,
        uint256 tokenAmount,
        uint256 bidId
    );

    error InsufficientBorrowerCollateral(uint256 required, uint256 actual);


    constructor(address _protocolAddress, address _marketRegistry)
        TellerV2MarketForwarder_G2(_protocolAddress, _marketRegistry)
    {
 
    }


        //register a smart contract (lender group) ? necessary ? 
        //maybe that contract just approves tokens to this contract ? 
   /*function registerSmartCommitment(  ) external {

   }*/

  /**
     * @notice Accept the commitment to submitBid and acceptBid using the funds
     * @dev LoanDuration must be longer than the market payment cycle
     * @param _smartCommitmentAddress The address of the smart commitment contract.
     * @param _principalAmount The amount of currency to borrow for the loan.
     * @param _collateralAmount The amount of collateral to use for the loan.
     * @param _collateralTokenId The tokenId of collateral to use for the loan if ERC721 or ERC1155.
     * @param _collateralTokenAddress The contract address to use for the loan collateral tokens.
     * @param _recipient The address to receive the loan funds.
     * @param _interestRate The interest rate APY to use for the loan in basis points.
     * @param _loanDuration The overall duration for the loan.  Must be longer than market payment cycle duration.
     * @return bidId The ID of the loan that was created on TellerV2
     */
    function acceptCommitmentWithRecipient(
        address _smartCommitmentAddress,
        uint256 _principalAmount,
        uint256 _collateralAmount,
        uint256 _collateralTokenId,
        address _collateralTokenAddress,
        address _recipient,
        uint16 _interestRate,
        uint32 _loanDuration
    ) public returns (uint256 bidId) {
        require(
            ISmartCommitment( _smartCommitmentAddress ).getCollateralTokenType() <=
                CommitmentCollateralType.ERC1155_ANY_ID,
            "Invalid commitment collateral type"
        );

        return
            _acceptCommitment(
                _smartCommitmentAddress,
                _principalAmount,
                _collateralAmount,
                _collateralTokenId,
                _collateralTokenAddress,
                _recipient,
                _interestRate,
                _loanDuration
            );
    }

    function _acceptCommitment(
        address _smartCommitmentAddress,
        uint256 _principalAmount,
        uint256 _collateralAmount,
        uint256 _collateralTokenId,
        address _collateralTokenAddress,
        address _recipient,
        uint16 _interestRate,
        uint32 _loanDuration
    ) internal returns (uint256 bidId) {
        ISmartCommitment _commitment = ISmartCommitment(_smartCommitmentAddress);
        
       

        //consider putting these into less readonly fn calls 
        require(
            _collateralTokenAddress == _commitment.collateralTokenAddress(),
            "Mismatching collateral token"
        );
        //the interest rate must be at least as high has the commitment demands. The borrower can use a higher interest rate although that would not be beneficial to the borrower.
        require(
            _interestRate >= _commitment.minInterestRate(),
            "Invalid interest rate"
        );
        //the loan duration must be less than the commitment max loan duration. The lender who made the commitment expects the money to be returned before this window.
        require(
            _loanDuration <= _commitment.maxDuration(),
            "Invalid loan max duration"
        );

       
           

    /*
     //commitmentPrincipalAccepted[bidId] <= commitment.maxPrincipal,

   //require that the borrower accepting the commitment cannot borrow more than the commitments max principal
        if (_principalAmount > commitment.maxPrincipal) {
            revert InsufficientCommitmentAllocation({
                allocated: commitment.maxPrincipal,
                requested: _principalAmount
            });
        }
    */
        require(
             _commitment.isAvailableToBorrow( _principalAmount),           
            "Invalid loan max principal"
        );

        require(
            _commitment.isAllowedToBorrow( _msgSender()  ),           
            "unauthorized borrow"
        );

 
        uint256 requiredCollateral = _commitment.getRequiredCollateral(
            _principalAmount 
        );

        if (_collateralAmount < requiredCollateral) {
            revert InsufficientBorrowerCollateral({
                required: requiredCollateral,
                actual: _collateralAmount
            });
        }

        CommitmentCollateralType commitmentCollateralTokenType = _commitment.getCollateralTokenType();

        //ERC721 assets must have a quantity of 1
        if (
            commitmentCollateralTokenType == 
            CommitmentCollateralType.ERC721 ||
            commitmentCollateralTokenType ==
            CommitmentCollateralType.ERC721_ANY_ID ||
            commitmentCollateralTokenType ==
            CommitmentCollateralType.ERC721_MERKLE_PROOF
        ) {
            require(
                _collateralAmount == 1,
                "invalid commitment collateral amount for ERC721"
            );
        }

        //ERC721 and ERC1155 types strictly enforce a specific token Id.  ERC721_ANY and ERC1155_ANY do not.
        if (
            commitmentCollateralTokenType == CommitmentCollateralType.ERC721 ||
            commitmentCollateralTokenType == CommitmentCollateralType.ERC1155
        ) { 
          uint256 commitmentCollateralTokenId = _commitment.getCollateralTokenId(); 

            require(
                commitmentCollateralTokenId == _collateralTokenId,
                "invalid commitment collateral tokenId"
            );
        }


        //do this accounting in the group contract now? 

        /*
        commitmentPrincipalAccepted[_commitmentId] += _principalAmount;

        require(
            commitmentPrincipalAccepted[_commitmentId] <=
                commitment.maxPrincipal,
            "Exceeds max principal of commitment"
        ); 
        
        
        */

        //this can only be called by contracts that the lending group contract has approved tokens to ..
        // so the group contract will designate this contract as being 'special '  
        _commitment.withdrawFundsForAcceptBid( 
            _principalAmount
        );

        uint256 commitmentMarketId = _commitment.marketId();
        address principalTokenAddress = _commitment.principalTokenAddress();

        CreateLoanArgs memory createLoanArgs;
        createLoanArgs.marketId = commitmentMarketId;
        createLoanArgs.lendingToken = principalTokenAddress;
        createLoanArgs.principal = _principalAmount;
        createLoanArgs.duration = _loanDuration;
        createLoanArgs.interestRate = _interestRate;
        createLoanArgs.recipient = _recipient;

        if (commitmentCollateralTokenType != CommitmentCollateralType.NONE) {
            createLoanArgs.collateral = new Collateral[](1);
            createLoanArgs.collateral[0] = Collateral({
                _collateralType: _getEscrowCollateralType(
                    commitmentCollateralTokenType
                ),
                _tokenId: _collateralTokenId,
                _amount: _collateralAmount,
                _collateralAddress: _collateralTokenAddress // commitment.collateralTokenAddress
            });
        }

        bidId = _submitBidWithCollateral(createLoanArgs, _msgSender());

        _acceptBid(
            bidId, 
            _smartCommitmentAddress //the lender is the smart commitment contract 
            );

        emit ExercisedSmartCommitment(
            _smartCommitmentAddress,
            _msgSender(),
            _principalAmount,
            bidId
        );
    }


  /**
     * @notice Return the collateral type based on the commitmentcollateral type.  Collateral type is used in the base lending protocol.
     * @param _type The type of collateral to be used for the loan.
     */
    function _getEscrowCollateralType(CommitmentCollateralType _type)
        internal
        pure
        returns (CollateralType)
    {
        if (_type == CommitmentCollateralType.ERC20) {
            return CollateralType.ERC20;
        }
        if (
            _type == CommitmentCollateralType.ERC721 ||
            _type == CommitmentCollateralType.ERC721_ANY_ID ||
            _type == CommitmentCollateralType.ERC721_MERKLE_PROOF
        ) {
            return CollateralType.ERC721;
        }
        if (
            _type == CommitmentCollateralType.ERC1155 ||
            _type == CommitmentCollateralType.ERC1155_ANY_ID ||
            _type == CommitmentCollateralType.ERC1155_MERKLE_PROOF
        ) {
            return CollateralType.ERC1155;
        }

        revert("Unknown Collateral Type");
    }

}
