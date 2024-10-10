// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../TellerV2MarketForwarder_G3.sol";
import "./extensions/ExtensionsContextUpgradeable.sol";
import "../interfaces/ILenderCommitmentForwarder.sol";
import "../interfaces/ISmartCommitmentForwarder.sol";
import "./LenderCommitmentForwarder_G1.sol";

import "../interfaces/IPausableTimestamp.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import { CommitmentCollateralType, ISmartCommitment } from "../interfaces/ISmartCommitment.sol";

 
contract SmartCommitmentForwarder is
    ExtensionsContextUpgradeable, //this should always be first for upgradeability
    TellerV2MarketForwarder_G3,
    PausableUpgradeable,  //this does add some storage but AFTER all other storage
    ISmartCommitmentForwarder,
    IPausableTimestamp
     {
    event ExercisedSmartCommitment(
        address indexed smartCommitmentAddress,
        address borrower,
        uint256 tokenAmount,
        uint256 bidId
    );

    error InsufficientBorrowerCollateral(uint256 required, uint256 actual);



    modifier onlyProtocolPauser() { 
        require( ITellerV2( _tellerV2 ).isPauser(_msgSender()) , "Sender not authorized");
        _;
    }


    modifier onlyProtocolOwner() { 
        require( Ownable( _tellerV2 ).owner() == _msgSender()  , "Sender not authorized");
        _;
    }

    uint256 public liquidationProtocolFeePercent; 


    constructor(address _protocolAddress, address _marketRegistry)
        TellerV2MarketForwarder_G3(_protocolAddress, _marketRegistry)
    {  }

    function initialize() public initializer {       
        __Pausable_init();
    }

    function setLiquidationProtocolFeePercent(uint256 _percent) 
    public onlyProtocolOwner { 
        //max is 100% 
        require( _percent <= 10000 , "invalid fee percent" );
        liquidationProtocolFeePercent = _percent;
    }

    function getLiquidationProtocolFeePercent() 
    public view returns (uint256){       
        return liquidationProtocolFeePercent ;
    }

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
    function acceptSmartCommitmentWithRecipient(
        address _smartCommitmentAddress,
        uint256 _principalAmount,
        uint256 _collateralAmount,
        uint256 _collateralTokenId,
        address _collateralTokenAddress,
        address _recipient,
        uint16 _interestRate,
        uint32 _loanDuration
    ) public whenNotPaused returns (uint256 bidId) {
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



    /**
     * @notice Lets the DAO/owner of the protocol implement an emergency stop mechanism.
     */
    function pause() public virtual onlyProtocolPauser whenNotPaused {
        _pause();
    }

    /**
     * @notice Lets the DAO/owner of the protocol undo a previously implemented emergency stop.
     */
    function unpause() public virtual onlyProtocolPauser whenPaused {
        setLastUnpausedAt();
        _unpause();
    }


    function getLastUnpausedAt() 
    public view 
    returns (uint256) {


        return Math.max(
            lastUnpausedAt,
            IPausableTimestamp(TELLER_V2).getLastUnpausedAt()
        )
        ;
 

    }


    function setLastUnpausedAt() internal {
        lastUnpausedAt =  block.timestamp;
    }


    // -----

        //Overrides
    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ExtensionsContextUpgradeable)
        returns (address sender)
    {
        return ExtensionsContextUpgradeable._msgSender();
    }
    
}
