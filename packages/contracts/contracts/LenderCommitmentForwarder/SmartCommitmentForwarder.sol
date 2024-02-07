// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../TellerV2MarketForwarder_G4.sol";

import "../interfaces/ILenderCommitmentForwarder.sol";
import "./LenderCommitmentForwarder_G1.sol";

import { CommitmentCollateralType, ISmartCommitment } from "../interfaces/ISmartCommitment.sol";

/*

Borrower approves this contract as being able to create loans on THEIR Behalf.

via  
_submitBidWithCollateral
and _acceptBid 


*/
contract SmartCommitmentForwarder is TellerV2MarketForwarder_G4 {
    event ExercisedSmartCommitment(
        address indexed smartCommitmentAddress,
        address borrower,
        uint256 tokenAmount,
        uint256 bidId
    );

    error InsufficientBorrowerCollateral(uint256 required, uint256 actual);

    constructor(address _protocolAddress, address _marketRegistry)
        TellerV2MarketForwarder_G3(_protocolAddress, _marketRegistry)
    {}

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
            ISmartCommitment(_smartCommitmentAddress)
                .getCollateralTokenType() <=
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
        ISmartCommitment _commitment = ISmartCommitment(
            _smartCommitmentAddress
        );

        CreateLoanArgs memory createLoanArgs;

        createLoanArgs.marketId = _commitment.getMarketId();
        createLoanArgs.lendingToken = _commitment.getPrincipalTokenAddress();
        createLoanArgs.principal = _principalAmount;
        createLoanArgs.duration = _loanDuration;
        createLoanArgs.interestRate = _interestRate;
        createLoanArgs.recipient = _recipient;

        CommitmentCollateralType commitmentCollateralTokenType = _commitment
            .getCollateralTokenType();

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




        //make the internals of this do -> _acceptBidWithRepaymentListener so 
        //the group contract itself if accepting the bid 'bidId' (line above) directly without having to spoof msg sender 
        _commitment.acceptFundsForAcceptBid(
            _msgSender(), //borrower
            bidId,
            _principalAmount,
            _collateralAmount,
            _collateralTokenAddress,
            _collateralTokenId,
            _loanDuration,
            _interestRate
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
