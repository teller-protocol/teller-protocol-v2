// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Contracts
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interfaces
import "../../../interfaces/ITellerV2.sol";
import "../../../interfaces/IProtocolFee.sol";
import "../../../interfaces/ITellerV2Storage.sol";
import "../../../interfaces/IMarketRegistry.sol";
//import "../../../interfaces/ISmartCommitmentForwarder.sol";
import "../../../interfaces/IFlashRolloverLoan.sol";
import "../../../libraries/NumbersLib.sol";
 
import "./LenderCommitmentGroupShares.sol";

import {LoanRepaymentInterestCollector} from "./LoanRepaymentInterestCollector.sol";

import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import {CommitmentCollateralType, ISmartCommitment} from "../../../interfaces/ISmartCommitment.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
 

contract LenderCommitmentGroup_Smart is 
ISmartCommitment ,
Initializable
{
    using AddressUpgradeable for address;
    using NumbersLib for uint256;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    //ITellerV2 public immutable TELLER_V2;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable SMART_COMMITMENT_FORWARDER;
    
    bool private _initialized;
    LenderCommitmentGroupShares public sharesToken;
    LoanRepaymentInterestCollector public interestCollector;



    IERC20 public principalToken;
    address public collateralTokenAddress;
    uint256 collateralTokenId;
    CommitmentCollateralType collateralTokenType;
    uint256 marketId;
    uint32 maxLoanDuration;
    uint16 minInterestRate;

    uint256 maxPrincipalPerCollateralAmount;

   
    //this is all of the principal tokens that have been committed to this contract minus all that have been withdrawn.  This includes the tokens in this contract and lended out in active loans by this contract. 
    
    //run lots of tests in which tokens are donated to this contract to be uncommitted to make sure things done break 
    // tokens donated to this contract should be ignored? 
  
    uint256 public totalPrincipalTokensCommitted;         //this can be less than we expect if tokens are donated to the contract and withdrawn 
    uint256 public totalPrincipalTokensUncommitted;  
    uint256 public totalPrincipalTokensWithdrawnForLending;

    uint256 public totalCollectedInterest;
    uint256 public totalInterestWithdrawn;

    mapping (address => uint256) public principalTokensCommittedByLender;
 

    modifier onlyInitialized{

        require(_initialized,"Contract must be initialized");
        _;

    } 

      modifier onlySmartCommitmentForwarder{

        require(msg.sender == address(SMART_COMMITMENT_FORWARDER),"Can only be called by Smart Commitment Forwarder");
        _;

    } 
  
            //maybe make this an initializer instead !? 
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
      //  address _tellerV2,
        address _smartCommitmentForwarder     
    ) {
       // TELLER_V2 = ITellerV2(_tellerV2);
        SMART_COMMITMENT_FORWARDER = _smartCommitmentForwarder;

        
    }
    
    // must send initial principal tokens into this contract just before this is called
    function initialize( 
        address _principalTokenAddress,

        address _collateralTokenAddress,

        uint256 _collateralTokenId,
        CommitmentCollateralType _collateralTokenType, 

        uint256 _marketId,
        uint32 _maxLoanDuration,
        uint16 _minInterestRate,

        uint256 _maxPrincipalPerCollateralAmount

         //ILenderCommitmentForwarder.Commitment calldata _createCommitmentArgs

    ) // initializer  ADD ME 
    external {

        _initialized = true;

        principalToken = IERC20(_principalTokenAddress);

      
        collateralTokenAddress = _collateralTokenAddress;
        collateralTokenId = _collateralTokenId;
        collateralTokenType = _collateralTokenType;
        marketId = _marketId;
        maxLoanDuration = _maxLoanDuration;
        minInterestRate = _minInterestRate;

        maxPrincipalPerCollateralAmount = _maxPrincipalPerCollateralAmount;
       // _createInitialCommitment(_createCommitmentArgs);


       //set initial terms in storage from _createCommitmentArgs

        _deploySharesToken();

        _deployInterestCollector();


    }
 
 

    function _deploySharesToken() internal {


       // uint256 principalTokenDecimals = principalToken.decimals();

        sharesToken =  new LenderCommitmentGroupShares(
            "Shares",
            "SHR",
            18   //may want this to equal the decimals of principal token !? 
        );

    }
    function _deployInterestCollector() internal {


       // uint256 principalTokenDecimals = principalToken.decimals();

        interestCollector =  new LoanRepaymentInterestCollector(
           address(principalToken)
        );

    }
    


  

    /*
    must be initialized for this to work ! 
    */
    function addPrincipalToCommitmentGroup(
        uint256 _amount,
        address _sharesRecipient
    ) external 
        onlyInitialized
    {

        //transfers the primary principal token from msg.sender into this contract escrow 
        //gives 
        principalToken.transferFrom(msg.sender, address(this), _amount );
  

        //mint shares equal to _amount and give them to the shares recipient !!! 
        sharesToken.mint( _sharesRecipient,_amount);

        totalPrincipalTokensCommitted += _amount;
        principalTokensCommittedByLender[msg.sender] += _amount;

    }


   function withdrawFundsForAcceptBid(
    address _borrower,
    uint256 _principalAmount, 

    uint256 _collateralAmount,
    address _collateralTokenAddress,
    uint256 _collateralTokenId,
    uint32 _loanDuration,

    uint16 _interestRate
            
  ) external onlySmartCommitmentForwarder
    {  



           //consider putting these into less readonly fn calls 
        require(
            _collateralTokenAddress == collateralTokenAddress,
            "Mismatching collateral token"
        );
        //the interest rate must be at least as high has the commitment demands. The borrower can use a higher interest rate although that would not be beneficial to the borrower.
        require(
            _interestRate >= minInterestRate,
            "Invalid interest rate"
        );
        //the loan duration must be less than the commitment max loan duration. The lender who made the commitment expects the money to be returned before this window.
        require(
            _loanDuration <= maxLoanDuration,
            "Invalid loan max duration"
        );
        
        require(
              getPrincipalAmountAvailableToBorrow() >=  _principalAmount,           
            "Invalid loan max principal"
        );

        require(
            isAllowedToBorrow( _borrower  ),           
            "unauthorized borrow"
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



     

        //do this accounting in the group contract now? 

        /*
        commitmentPrincipalAccepted[_commitmentId] += _principalAmount;

        require(
            commitmentPrincipalAccepted[_commitmentId] <=
                commitment.maxPrincipal,
            "Exceeds max principal of commitment"
        ); 
        
        
        */


 
        uint256 requiredCollateral =  getRequiredCollateral(
            _principalAmount 
        );

        require (_collateralAmount < requiredCollateral , "Insufficient Borrower Collateral" ) ;

        CommitmentCollateralType commitmentCollateralTokenType = collateralTokenType;

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
         
            require(
                _collateralTokenId == collateralTokenId,
                "invalid commitment collateral tokenId"
            );
        }

 




       
        principalToken.transfer( SMART_COMMITMENT_FORWARDER, _principalAmount );

        totalPrincipalTokensWithdrawnForLending += _principalAmount;

       //emit event 
    }

   /*
    must be initialized for this to work ! 
    */
    function burnSharesToWithdrawEarnings(
        uint256 _amountSharesTokens,
        address _recipient
    ) external 
    onlyInitialized
    {   


            //pull interest from interest collector 
                //
        uint256 collectedInterest = LoanRepaymentInterestCollector( interestCollector ).collectInterest();
        totalCollectedInterest += collectedInterest;


        //figure out the ratio of shares tokens that this is 
        uint256 sharesTotalSupplyBeforeBurn = sharesToken.totalSupply();

        //this DOES reduce total supply! This is necessary for correct math. 
        sharesToken.burn( msg.sender, _amountSharesTokens );


        /*  
        The fraction of shares that was just burned has 
        a numerator of _amount and 
        a denominator of sharesTotalSupplyBeforeBurn !
        */

        /*
            In this flow, lenders who withdraw first are able to claim the liquid tokens first 
            while the illiquid assets remain withdrawable by the remaining lenders at a later time. 

        */


        uint256 principalTokenBalance = principalToken.balanceOf(address(this));


       
        uint256 netCommittedTokens = totalPrincipalTokensCommitted - totalPrincipalTokensUncommitted; 


            //hopefully this is correct ?  have to make sure it isnt negative tho ? 
       // uint256 totalLendedTokensRepaidFromLending = (principalTokenBalance + totalPrincipalTokensUncommitted + totalPrincipalTokensWithdrawnForLending) - (totalPrincipalTokensCommitted + totalCollectedInterest );
 
 
       // uint256 principalTokenEquityAmount = principalTokenBalance + totalPrincipalTokensWithdrawnForLending - totalLendedTokensRepaidFromLending ;

      

        uint256 principalTokenEquityAmountSimple =  totalPrincipalTokensCommitted + totalCollectedInterest - (totalPrincipalTokensUncommitted  + totalInterestWithdrawn);

        uint256 principalTokenAmountToWithdraw = principalTokenEquityAmountSimple * _amountSharesTokens / sharesTotalSupplyBeforeBurn;
        uint256 tokensToUncommit = netCommittedTokens * _amountSharesTokens / sharesTotalSupplyBeforeBurn;

        totalPrincipalTokensUncommitted += tokensToUncommit;

        totalInterestWithdrawn += principalTokenAmountToWithdraw - tokensToUncommit;


        //totalPrincipalTokensCommitted -= principalTokenAmountToWithdraw;
        principalTokensCommittedByLender[msg.sender] -= principalTokenAmountToWithdraw;

        sharesToken.transfer( _recipient, principalTokenAmountToWithdraw );

        
  
    }



    function getCollateralTokenAddress() external view returns (address){

        return collateralTokenAddress; 
    }

    function getCollateralTokenId() external view returns (uint256){

        return collateralTokenId;
    }

    function getCollateralTokenType() external view returns (CommitmentCollateralType){

        return collateralTokenType;
    }
   
    function getRequiredCollateral(uint256 _principalAmount) public view returns (uint256){

       return _getRequiredCollateral(
         _principalAmount,
        maxPrincipalPerCollateralAmount,
        collateralTokenType,
        collateralTokenAddress,
        address (principalToken)
       );

    }
      
    function getMarketId() external view returns (uint256){

        return marketId;
    }
   
   function getMaxLoanDuration() external view returns (uint32){

    return maxLoanDuration;
   }
    
    function getMinInterestRate() external view returns (uint16){

        return minInterestRate;
    }
    
    function getPrincipalTokenAddress() external view returns (address){

    return address(principalToken);
   }    

   
    function isAllowedToBorrow(address borrower) public view returns (bool){

        return true ;
    }
   
    function getPrincipalAmountAvailableToBorrow( ) public view returns (uint256){

        uint256 amountAvailable = totalPrincipalTokensCommitted
         - totalPrincipalTokensWithdrawnForLending
        ;

        return amountAvailable;
    
    }

    
       /**
     * @notice Calculate the amount of collateral required to borrow a loan with _principalAmount of principal
     * @param _principalAmount The amount of currency to borrow for the loan.
     * @param _maxPrincipalPerCollateralAmount The ratio for the amount of principal that can be borrowed for each amount of collateral. This is expanded additionally by the principal decimals.
     * @param _collateralTokenType The type of collateral for the loan either ERC20, ERC721, ERC1155, or None.
     * @param _collateralTokenAddress The contract address for the collateral for the loan.
     * @param _principalTokenAddress The contract address for the principal for the loan.
     */
    function _getRequiredCollateral(
        uint256 _principalAmount,
        uint256 _maxPrincipalPerCollateralAmount,
        CommitmentCollateralType _collateralTokenType,
        address _collateralTokenAddress,
        address _principalTokenAddress
    ) internal view virtual returns (uint256) {
        if (_collateralTokenType == CommitmentCollateralType.NONE) {
            return 0;
        }

        uint8 collateralDecimals;
        uint8 principalDecimals = IERC20MetadataUpgradeable(
            _principalTokenAddress
        ).decimals();

        if (_collateralTokenType == CommitmentCollateralType.ERC20) {
            collateralDecimals = IERC20MetadataUpgradeable(
                _collateralTokenAddress
            ).decimals();
        }

        /*
         * The principalAmount is expanded by (collateralDecimals+principalDecimals) to increase precision
         * and then it is divided by _maxPrincipalPerCollateralAmount which should already been expanded by principalDecimals
         */
        return
            MathUpgradeable.mulDiv(
                _principalAmount,
                (10**(collateralDecimals + principalDecimals)),
                _maxPrincipalPerCollateralAmount,
                MathUpgradeable.Rounding.Up
            );
    }


   
 

}
