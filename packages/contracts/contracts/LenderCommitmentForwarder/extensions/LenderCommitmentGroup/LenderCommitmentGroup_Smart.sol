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

import "../../../interfaces/uniswap/IUniswapV3Pool.sol";
 
import "./LenderCommitmentGroupShares.sol";
 
import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import {CommitmentCollateralType, ISmartCommitment} from "../../../interfaces/ISmartCommitment.sol";
import {ILoanRepaymentListener} from "../../../interfaces/ILoanRepaymentListener.sol";



import {ILenderCommitmentGroup} from "../../../interfaces/ILenderCommitmentGroup.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
 

/*



////----


1. Use 50% forced max utilization ratio as initial game theory - have a global utilization limit and a user-signalled utilization limit (based on shares signalling) 

2. When pool shares are burned, give the lender : [ their pct shares *  ( currentPrincipalTokens in contract, totalCollateralShares, totalInterestCollected)   ] and later, they can burn the collateral shares for any collateral tokens that are in the contract. 
3. use noahs TToken contract as reference for ratios -> amt of tokens to get when committing 
4.  Need price oracle bc we dont want to use maxPrincipalPerCollateral ratio as a static ideally 
5. have an LTV ratio 

Every time a lender deposits tokens, we can mint an equal amt of RepresentationToken




// -- EXITING 

When exiting, a lender is burning X shares 

 -  We calculate the total equity value (Z) of the pool  multiplies by their pct of shares (S%)    (naive is just total committed princ tokens and interest , could maybe do better  )
    - We are going to give the lender  (Z * S%) value.  The way we are going to give it to them is in a split of principal (P) and collateral tokens (C)  which are in the pool right now.   Similar to exiting a uni pool .   C tokens will only be in the pool if bad defaults happened.  
    
         NOTE:  We will know the price of C in terms of P due to the ratio of total P used for loans and total C used for loans 
         
         NOTE: if there are not enough P and C tokens in the pool to give the lender to equal a value of (Z * S%) then we revert . 

// ---------



// TODO 


 1.   implement the LTV  along with the uniswap oracle price ( they BOTH are used to figure out required collateral per principal for a new loan accept )

 2. implement share mints scaling by looking at TToken code  (make a fn to find a ratio of committed principal token value to total pool equity value atm   --difference should be the interest in a naive design) 

 3. finish off the exiting split tokens logic 

 4. tests 

// ----




AAve utilization rate is 50% lets say 
no matter what , only 50 pct of 100 can be out on loan.




If a lender puts up 50,000 originally, im able to withdraw all my deposits.  Everyone else is in the hole until a borrower repays a loan 
If there isnt enough liquidity, you just cannot burn those shares. 

 
  
 
Consider implementing eip-4626


*/





contract LenderCommitmentGroup_Smart is 
ILenderCommitmentGroup ,
ISmartCommitment ,
ILoanRepaymentListener,
Initializable
{
    using AddressUpgradeable for address;
    using NumbersLib for uint256;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    //ITellerV2 public immutable TELLER_V2;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable SMART_COMMITMENT_FORWARDER;
    address public immutable UNISWAP_V3_POOL; 
    
    bool private _initialized;
   
    LenderCommitmentGroupShares public poolSharesToken;
   // LenderCommitmentGroupShares public collateralSharesToken;
 

   
    IERC20 public principalToken;
    IERC20 public collateralToken;
   // address public collateralTokenAddress;
  //  uint256 collateralTokenId;
  //  CommitmentCollateralType collateralTokenType;
    uint256 marketId;
    uint32 maxLoanDuration;
    uint16 minInterestRate;

    //uint256 maxPrincipalPerCollateralAmount;

   
    //this is all of the principal tokens that have been committed to this contract minus all that have been withdrawn.  This includes the tokens in this contract and lended out in active loans by this contract. 
    
    //run lots of tests in which tokens are donated to this contract to be uncommitted to make sure things done break 
    // tokens donated to this contract should be ignored? 
  
    uint256 public totalPrincipalTokensCommitted;         //this can be less than we expect if tokens are donated to the contract and withdrawn 
   
    uint256 public totalPrincipalTokensLended;
    uint256 public totalPrincipalTokensRepaid;      //subtract this and the above to find total principal tokens outstanding for loans 

 
    uint256 public totalCollateralTokensEscrowedForLoans; // we use this in conjunction with totalPrincipalTokensLended for a psuedo TWAP price oracle of C tokens, used for exiting  .  Nice bc it is averaged over all of our relevant loans, not the current price.  


    uint256 public totalInterestCollected;
    uint256 public totalInterestWithdrawn;

    uint16 public liquidityThresholdPercent;  //5000 is 50 pct  // enforce max of 10000
    uint16 public loanToValuePercent; //the overcollateralization ratio, typically 80 pct 

    mapping (address => uint256) public principalTokensCommittedByLender;
   
   //try to make apy dynamic . 
    

    modifier onlyAfterInitialized{

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
        address _smartCommitmentForwarder,
        address _uniswapV3Pool
    ) {
       // TELLER_V2 = ITellerV2(_tellerV2);
        SMART_COMMITMENT_FORWARDER = _smartCommitmentForwarder;
        UNISWAP_V3_POOL = _uniswapV3Pool;
        
    }
    
    // must send initial principal tokens into this contract just before this is called
    function initialize( 
        address _principalTokenAddress,

        address _collateralTokenAddress,

       // uint256 _collateralTokenId,
       // CommitmentCollateralType _collateralTokenType, 

        uint256 _marketId,
        uint32 _maxLoanDuration,
        uint16 _minInterestRate,

        uint16 _liquidityThresholdPercent,
        uint16 _loanToValuePercent //essentially the overcollateralization ratio.  10000 is 1:1 baseline ?

        //uint256 _maxPrincipalPerCollateralAmount //use oracle instead 

         //ILenderCommitmentForwarder.Commitment calldata _createCommitmentArgs

    ) // initializer  ADD ME 
    external returns (address poolSharesToken_) {

        _initialized = true;

        principalToken = IERC20(_principalTokenAddress);
        collateralToken = IERC20(_collateralTokenAddress);

      
        // collateralTokenAddress = _collateralTokenAddress;
        // collateralTokenId = _collateralTokenId;
        // collateralTokenType = _collateralTokenType;
        marketId = _marketId;
        maxLoanDuration = _maxLoanDuration;
        minInterestRate = _minInterestRate;


        require( _liquidityThresholdPercent <= 10000 , "invalid threshold" );

        liquidityThresholdPercent = _liquidityThresholdPercent;
        loanToValuePercent = _loanToValuePercent;

        // maxPrincipalPerCollateralAmount = _maxPrincipalPerCollateralAmount;
        // _createInitialCommitment(_createCommitmentArgs);


        // set initial terms in storage from _createCommitmentArgs

        poolSharesToken_ =  _deployPoolSharesToken();
 
  

    }
 
 

    function _deployPoolSharesToken() internal returns (address poolSharesToken_)  {
       // uint256 principalTokenDecimals = principalToken.decimals();

        poolSharesToken =  new LenderCommitmentGroupShares(
            "PoolShares",
            "PSH",
            18   //may want this to equal the decimals of principal token !? 
        );

        return address(poolSharesToken);
    } 

  

    /*
    must be initialized for this to work ! 
    */
    function addPrincipalToCommitmentGroup(
        uint256 _amount,
        address _sharesRecipient
    ) external 
        onlyAfterInitialized
        returns (uint256 sharesAmount_)
    {

        //transfers the primary principal token from msg.sender into this contract escrow 
        //gives 
        principalToken.transferFrom(msg.sender, address(this), _amount );

    

        totalPrincipalTokensCommitted += _amount;
        principalTokensCommittedByLender[msg.sender] += _amount;


        //calculate this !! from ratio  TODO 
        /*
        Should get slightly less shares than principal tokens put in !! diluted by ratio of pools actual equity 
        */
        uint256 undilutedSharedAmount = _amount;

        uint256 poolTotalEstimatedValue = totalPrincipalTokensCommitted + totalInterestCollected;
        sharesAmount_ =  undilutedSharedAmount * totalPrincipalTokensCommitted  /  poolTotalEstimatedValue ;

        //mint shares equal to _amount and give them to the shares recipient !!! 
        poolSharesToken.mint( _sharesRecipient,sharesAmount_);

    }


   function acceptFundsForAcceptBid(
    address _borrower,
    uint256 _principalAmount, 

    uint256 _collateralAmount,
    address _collateralTokenAddress,
    uint256 _collateralTokenId,  //not used 
    uint32 _loanDuration,

    uint16 _interestRate
            
  ) external onlySmartCommitmentForwarder
    {  



           //consider putting these into less readonly fn calls 
        require(
            _collateralTokenAddress == address(collateralToken),
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

      /*  CommitmentCollateralType commitmentCollateralTokenType = collateralTokenType;

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

        */




       
        principalToken.transfer( SMART_COMMITMENT_FORWARDER, _principalAmount );

        totalPrincipalTokensLended += _principalAmount;

       //emit event 
    }


    

   /*
    must be initialized for this to work ! 
    */
    function burnSharesToWithdrawEarnings(
        uint256 _amountPoolSharesTokens,
        address _recipient
    ) external 
    onlyAfterInitialized
    {   
 
                //
        //uint256 collectedInterest = LoanRepaymentInterestCollector( interestCollector ).collectInterest();
       


        //figure out the ratio of shares tokens that this is 
        uint256 poolSharesTotalSupplyBeforeBurn = poolSharesToken.totalSupply();

        //this DOES reduce total supply! This is necessary for correct math. 
        poolSharesToken.burn( msg.sender, _amountPoolSharesTokens );


 


       
        uint256 netCommittedTokens = totalPrincipalTokensCommitted; 

      

        uint256 principalTokenEquityAmountSimple =  totalPrincipalTokensCommitted + totalInterestCollected - ( totalInterestWithdrawn);

        uint256 principalTokenValueToWithdraw = principalTokenEquityAmountSimple * _amountPoolSharesTokens / poolSharesTotalSupplyBeforeBurn;
        uint256 tokensToUncommit = netCommittedTokens * _amountPoolSharesTokens / poolSharesTotalSupplyBeforeBurn;

        totalPrincipalTokensCommitted -= tokensToUncommit;
       // totalPrincipalTokensUncommitted += tokensToUncommit;

        totalInterestWithdrawn += principalTokenValueToWithdraw - tokensToUncommit;


         


        principalTokensCommittedByLender[msg.sender] -= principalTokenValueToWithdraw;
       

        //implement this --- needs to be based on the amt of tokens in the contract right now !! 
        (uint256 principalTokenSplitAmount, uint256 collateralTokenSplitAmount) = calculateSplitTokenAmounts( principalTokenValueToWithdraw );
       
        principalToken.transfer( _recipient, principalTokenSplitAmount );
        collateralToken.transfer( _recipient, collateralTokenSplitAmount );


        //also mint collateral token shares !!  or give them out . 
        
  
    }


    
    function calculateSplitTokenAmounts( uint256 _principalTokenAmountValue ) 
      public view returns (uint256 principalAmount_, uint256 collateralAmount_ ) {

        // need to see how many collateral tokens are in the contract atm 

        // need to know how many principal tokens are in the contract atm 


    //  need to know how the value of the collateral tokens  IN TERMS OF principal tokens 

 

        //these should both add up to equal the input:  _principalTokenAmountValue
      uint256 principalTokenAmountValueToGiveInPrincipalTokens;
      uint256 principalTokenAmountValueToGiveInCollateralTokens;  


      uint256 collateralTokensToGive ;


      return (principalTokenAmountValueToGiveInPrincipalTokens , collateralTokensToGive);
    } 







/*
consider passing in both token addresses and then get pool address from that 
*/  

    //this depends on current oracle price from uniswap 

    function getMaxPrincipalPerCollateralAmount(  ) public view returns (uint256) {


    }   


/*
//move this into the factory for this contract 
    function getUniswapV3PoolAddress(address tokenA, address tokenB, uint24 fee) 
    internal view returns (address) {
        address poolAddress = UNISWAP_V3_FACTORY.getPool(tokenA, tokenB, fee);
        return poolAddress;
    }
    */
    
    function _getUniswapV3TokenPrice(address poolAddress) 
    internal view returns (uint256) {
      //  IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(UNISWAP_V3_POOL).slot0();
        
        // sqrtPrice is in X96 format so we scale it down to get the price
        // Also note that this price is a relative price between the two tokens in the pool
        // It's not a USD price
        uint256 price = uint256(sqrtPriceX96) * (sqrtPriceX96) * (1e18) >> (96 * 2);
        
        return price;
    }


    function repayLoanCallback(
        uint256 _bidId, 
        address repayer, 
        uint256 principalAmount, 
        uint256 interestAmount
    ) external  {
            //can use principal amt to increment amt paid back!! nice for math . 
            totalPrincipalTokensRepaid += principalAmount; 
            totalInterestCollected += interestAmount;
    }
 




    function getAverageWeightedPriceForCollateralTokensPerPrincipalTokens( ) public view returns (uint256) {

        if( totalPrincipalTokensLended <= 0 ){ return 0 ;}

        return  totalCollateralTokensEscrowedForLoans / totalPrincipalTokensLended;
    }


   function getTotalPrincipalTokensOutstandingInActiveLoans() public view returns (uint256) {

         return totalPrincipalTokensLended - totalPrincipalTokensRepaid; 
  

   }

    function getCollateralTokenAddress() external view returns (address){

        return address(collateralToken); 
    }

    

    function getCollateralTokenId() external view returns (uint256){

        return 0;
    }

    function getCollateralTokenType() external view returns (CommitmentCollateralType){

        return CommitmentCollateralType.ERC20;
    }
   

    function getRequiredCollateral(uint256 _principalAmount) public view returns (uint256){


      uint256 maxPrincipalPerCollateralAmount = getMaxPrincipalPerCollateralAmount( );

       return _getRequiredCollateral(
         _principalAmount,
        maxPrincipalPerCollateralAmount,
        //collateralTokenType,
        address(collateralToken),
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

        uint256 totalAmountAvailable;  

        uint256 amountAvailable = totalPrincipalTokensCommitted
         - getTotalPrincipalTokensOutstandingInActiveLoans() 
        ;

        return totalAmountAvailable.percent( liquidityThresholdPercent );
    
    }

    
       /**
     * @notice Calculate the amount of collateral required to borrow a loan with _principalAmount of principal
     * @param _principalAmount The amount of currency to borrow for the loan.
     * @param _maxPrincipalPerCollateralAmount The ratio for the amount of principal that can be borrowed for each amount of collateral. This is expanded additionally by the principal decimals.
     * @param _collateralTokenAddress The contract address for the collateral for the loan.
     * @param _principalTokenAddress The contract address for the principal for the loan.
     */
    function _getRequiredCollateral(
        uint256 _principalAmount,
        uint256 _maxPrincipalPerCollateralAmount,
      //  CommitmentCollateralType _collateralTokenType,
        address _collateralTokenAddress,
        address _principalTokenAddress
    ) internal view virtual returns (uint256) {
        

        uint8 collateralDecimals;
        uint8 principalDecimals = IERC20MetadataUpgradeable(
            _principalTokenAddress
        ).decimals();

       // if (_collateralTokenType == CommitmentCollateralType.ERC20) {
            collateralDecimals = IERC20MetadataUpgradeable(
                _collateralTokenAddress
            ).decimals();
       // }

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
