// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

  
// Contracts
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


// Interfaces
import "../../../interfaces/ITellerV2Context.sol";
import "../../../interfaces/IProtocolFee.sol";
 
import "../../../interfaces/ITellerV2.sol";

import "../../../libraries/NumbersLib.sol";

import "../../../interfaces/uniswap/IUniswapV3Pool.sol";


import "../../../interfaces/IHasProtocolPausingManager.sol";

import "../../../interfaces/IProtocolPausingManager.sol";



import "../../../interfaces/uniswap/IUniswapV3Factory.sol";
import "../../../interfaces/ISmartCommitmentForwarder.sol";

import "../../../libraries/uniswap/TickMath.sol";
import "../../../libraries/uniswap/FixedPoint96.sol";
import "../../../libraries/uniswap/FullMath.sol";
 

import { LenderCommitmentGroupSharesIntegrated } from "./LenderCommitmentGroupSharesIntegrated.sol";

import {OracleProtectedChild} from "../../../oracleprotection/OracleProtectedChild.sol";

import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";



import { IERC4626  } from "../../../interfaces/IERC4626.sol";

import { CommitmentCollateralType, ISmartCommitment } from "../../../interfaces/ISmartCommitment.sol";
import { ILoanRepaymentListener } from "../../../interfaces/ILoanRepaymentListener.sol";

import { ILoanRepaymentCallbacks } from "../../../interfaces/ILoanRepaymentCallbacks.sol";

import { IEscrowVault } from "../../../interfaces/IEscrowVault.sol";

import { IPausableTimestamp } from "../../../interfaces/IPausableTimestamp.sol";
import { ILenderCommitmentGroup_V2 } from "../../../interfaces/ILenderCommitmentGroup_V2.sol";
import { Payment } from "../../../TellerV2Storage.sol";

import {IUniswapPricingLibrary} from "../../../interfaces/IUniswapPricingLibrary.sol";
import {UniswapPricingLibraryV2} from "../../../libraries/UniswapPricingLibraryV2.sol";


import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

 

/*
 

 Each LenderCommitmentGroup SmartContract acts as its own Loan Commitment (for the SmartCommitmentForwarder) and acts as its own Lender in the Teller Protocol.

 Lender Users can deposit principal tokens in this contract and this will give them Share Tokens (LP tokens) representing their ownership in the liquidity pool of this contract.

 Borrower Users can borrow principal token funds from this contract (via the SCF contract) by providing collateral tokens in the proper amount as specified by the rules of this smart contract.
 These collateral tokens are then owned by this smart contract and are returned to the borrower via the Teller Protocol rules to the borrower if and only if the borrower repays principal and interest of the loan they took.

 If the borrower defaults on a loan, for 24 hours a liquidation auction is automatically conducted by this smart contract in order to incentivize a liquidator to take the collateral tokens in exchange for principal tokens.


*/

contract LenderCommitmentGroup_Pool_V2 is
    ILenderCommitmentGroup_V2,
    IERC4626, // interface functions for lenders 
    ISmartCommitment, // interface functions for borrowers (teller protocol) 
    ILoanRepaymentListener,
    IPausableTimestamp,
    Initializable,
    OracleProtectedChild,
    OwnableUpgradeable,    
    ReentrancyGuardUpgradeable,
    LenderCommitmentGroupSharesIntegrated
{
    using AddressUpgradeable for address;
    using NumbersLib for uint256;

    uint256 public immutable STANDARD_EXPANSION_FACTOR = 1e18;

    uint256 public immutable MIN_TWAP_INTERVAL = 3;

    uint256 public immutable UNISWAP_EXPANSION_FACTOR = 2**96;

    uint256 public immutable EXCHANGE_RATE_EXPANSION_FACTOR = 1e36;  

    using SafeERC20 for IERC20;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable TELLER_V2;
    address public immutable SMART_COMMITMENT_FORWARDER;
    address public immutable UNISWAP_V3_FACTORY;
    
  

    IERC20 public principalToken;
    IERC20 public collateralToken;

    uint256 marketId;


    uint256 public totalPrincipalTokensCommitted; 
    uint256 public totalPrincipalTokensWithdrawn;

    uint256 public totalPrincipalTokensLended;
    uint256 public totalPrincipalTokensRepaid; //subtract this and the above to find total principal tokens outstanding for loans
    uint256 public excessivePrincipalTokensRepaid;

    uint256 public totalInterestCollected;

    uint16 public liquidityThresholdPercent; //max ratio of principal allowed to be borrowed vs escrowed  //  maximum of 10000 (100%)
    uint16 public collateralRatio; //the overcollateralization ratio, typically >100 pct

    uint32 public maxLoanDuration;
    uint16 public interestRateLowerBound;
    uint16 public interestRateUpperBound;




    uint256 immutable public DEFAULT_WITHDRAW_DELAY_TIME_SECONDS = 300;
    uint256 immutable public MAX_WITHDRAW_DELAY_TIME = 86400;

    mapping(uint256 => bool) public activeBids;
    mapping(uint256 => uint256) public activeBidsAmountDueRemaining;

    int256 tokenDifferenceFromLiquidations;

    bool public firstDepositMade;
    uint256 public withdrawDelayTimeSeconds; 

    IUniswapPricingLibrary.PoolRouteConfig[]  public  poolOracleRoutes;

    //configured by the owner. If 0 , not used. 
    uint256 public maxPrincipalPerCollateralAmount; 


    uint256 public lastUnpausedAt;
    bool public paused;
    bool public borrowingPaused;
    bool public liquidationAuctionPaused;
   

    event PoolInitialized(
        address indexed principalTokenAddress,
        address indexed collateralTokenAddress,
        uint256 marketId,
        uint32 maxLoanDuration,
        uint16 interestRateLowerBound,
        uint16 interestRateUpperBound,
        uint16 liquidityThresholdPercent,
        uint16 loanToValuePercent 
    );
 


    event BorrowerAcceptedFunds(
        address indexed borrower,
        uint256 indexed bidId,
        uint256 principalAmount,
        uint256 collateralAmount,
        uint32 loanDuration,
        uint16 interestRate
    );

   

    event DefaultedLoanLiquidated(
        uint256 indexed bidId,
        address indexed liquidator,
        uint256 amountDue, 
        int256 tokenAmountDifference 
    );


    event LoanRepaid(
        uint256 indexed bidId,
        address indexed repayer,
        uint256 principalAmount,
        uint256 interestAmount,
        uint256 totalPrincipalRepaid,
        uint256 totalInterestCollected
    );


    event WithdrawFromEscrow(
       
        uint256  indexed amount

    );


    modifier onlySmartCommitmentForwarder() {
        require(
            msg.sender == address(SMART_COMMITMENT_FORWARDER),
            "OSCF"
        );
        _;
    }

    modifier onlyTellerV2() {
        require(
            msg.sender == address(TELLER_V2),
            "OTV2"
        );
        _;
    }


    modifier onlyProtocolOwner() {
        require(
            msg.sender == Ownable(address(TELLER_V2)).owner(),
            "OO"
        );
        _;
    }

    modifier onlyProtocolPauser() {

        address pausingManager = IHasProtocolPausingManager( address(TELLER_V2) ).getProtocolPausingManager();

        require(
           IProtocolPausingManager( pausingManager ).isPauser(msg.sender)  ,
            "OP"
        );
        _;
    }

    modifier bidIsActiveForGroup(uint256 _bidId) {
        require(activeBids[_bidId] == true, "BNA");

        _;
    }
 

    modifier whenForwarderNotPaused() {
         require( PausableUpgradeable(address(SMART_COMMITMENT_FORWARDER)).paused() == false , "SCF_P");
        _;
    }



    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _tellerV2,
        address _smartCommitmentForwarder,
        address _uniswapV3Factory
    ) OracleProtectedChild(_smartCommitmentForwarder) {
        TELLER_V2 = _tellerV2;
        SMART_COMMITMENT_FORWARDER = _smartCommitmentForwarder;
        UNISWAP_V3_FACTORY = _uniswapV3Factory;
    }

    /**
     * @notice Initializes the LenderCommitmentGroup_Smart contract.
     * @param _commitmentGroupConfig Configuration for the commitment group (lending pool).
     * @param _poolOracleRoutes Route configuration for the principal/collateral oracle.

     */
   function initialize(

       CommitmentGroupConfig calldata _commitmentGroupConfig,
     
       IUniswapPricingLibrary.PoolRouteConfig[] calldata _poolOracleRoutes 
         
    ) external initializer   {
       
        __Ownable_init();
    
        __Shares_init(
            _commitmentGroupConfig.principalTokenAddress,
            _commitmentGroupConfig.collateralTokenAddress
        ); //initialize the integrated shares 

        principalToken = IERC20(_commitmentGroupConfig.principalTokenAddress);
        collateralToken = IERC20(_commitmentGroupConfig.collateralTokenAddress);
         
        marketId = _commitmentGroupConfig.marketId;

        withdrawDelayTimeSeconds = DEFAULT_WITHDRAW_DELAY_TIME_SECONDS;

        //in order for this to succeed, first, the SmartCommitmentForwarder needs to be a trusted forwarder for the market         
        ITellerV2Context(TELLER_V2).approveMarketForwarder(
            _commitmentGroupConfig.marketId,
            SMART_COMMITMENT_FORWARDER
        );

        maxLoanDuration = _commitmentGroupConfig.maxLoanDuration;
        interestRateLowerBound = _commitmentGroupConfig.interestRateLowerBound;
        interestRateUpperBound = _commitmentGroupConfig.interestRateUpperBound;

        require(interestRateLowerBound <= interestRateUpperBound, "IRLB");

       
        liquidityThresholdPercent = _commitmentGroupConfig.liquidityThresholdPercent;
        collateralRatio = _commitmentGroupConfig.collateralRatio;
      
        require( liquidityThresholdPercent <= 10000, "ILTP"); 

        for (uint256 i = 0; i < _poolOracleRoutes.length; i++) {
            poolOracleRoutes.push(_poolOracleRoutes[i]);
        }


        require(poolOracleRoutes.length >= 1 && poolOracleRoutes.length <= 2, "PRL");
        
       
        emit PoolInitialized(
            _commitmentGroupConfig.principalTokenAddress,
            _commitmentGroupConfig.collateralTokenAddress,
            _commitmentGroupConfig.marketId,
            _commitmentGroupConfig.maxLoanDuration,
            _commitmentGroupConfig.interestRateLowerBound,
            _commitmentGroupConfig.interestRateUpperBound,
            _commitmentGroupConfig.liquidityThresholdPercent,
            _commitmentGroupConfig.collateralRatio
        );
    }



    /**
     * @notice Validates loan parameters and starts the TellerV2 Loan where this contract as the lender.
     * @dev Must be called via the Smart Commitment Forwarder 
     * @param _borrower Address of the borrower accepting the loan.
     * @param _bidId Identifier for the loan bid.
     * @param _principalAmount Amount of principal being lent.
     * @param _collateralAmount Amount of collateral provided by the borrower.
     * @param _collateralTokenAddress Address of the collateral token contract.
     * @param _collateralTokenId Token ID of the collateral (if applicable).
     * @param _loanDuration Duration of the loan in seconds.
     * @param _interestRate Interest rate for the loan, scaled by 100 (e.g., 500 = 5%).
     */
    function acceptFundsForAcceptBid(
        address _borrower,
        uint256 _bidId,
        uint256 _principalAmount,
        uint256 _collateralAmount,
        address _collateralTokenAddress,
        uint256 _collateralTokenId, 
        uint32 _loanDuration,
        uint16 _interestRate
    ) external onlySmartCommitmentForwarder whenForwarderNotPaused whenNotPaused whenBorrowingNotPaused {
        
        require(
            _collateralTokenAddress == address(collateralToken),
            "MMCT"
        );
        //the interest rate must be at least as high has the commitment demands. The borrower can use a higher interest rate although that would not be beneficial to the borrower.
        require(_interestRate >= getMinInterestRate(_principalAmount), "IIR");
        //the loan duration must be less than the commitment max loan duration. The lender who made the commitment expects the money to be returned before this window.
        require(_loanDuration <= maxLoanDuration, "LMD");

        require(
            getPrincipalAmountAvailableToBorrow() >= _principalAmount,
            "LMP"
        );
 
 
        uint256 requiredCollateral = calculateCollateralRequiredToBorrowPrincipal(
            _principalAmount
        );



        require(    
             _collateralAmount   >=
                requiredCollateral,
            "C"
        );
 
        principalToken.safeApprove(address(TELLER_V2), _principalAmount);

        //do not have to override msg.sender here as this contract is the lender !
        _acceptBidWithRepaymentListener(_bidId);

        totalPrincipalTokensLended += _principalAmount;

        activeBids[_bidId] = true; //bool for now
        activeBidsAmountDueRemaining[_bidId] =  _principalAmount;
        

        emit BorrowerAcceptedFunds(  
            _borrower,
            _bidId,
            _principalAmount,
            _collateralAmount, 
            _loanDuration,
            _interestRate 
         );
    }

    /**
    * @notice Internal function to accept a loan bid and set a repayment listener.
    * @dev Interacts with the Teller Protocol to accept the bid and register the repayment listener.
    * @param _bidId Identifier for the loan bid being accepted.
    */
    function _acceptBidWithRepaymentListener(uint256 _bidId) internal {

        ITellerV2(TELLER_V2).lenderAcceptBid(_bidId); //this gives out the funds to the borrower

        ILoanRepaymentCallbacks(TELLER_V2).setRepaymentListenerForBid(
            _bidId,
            address(this)
        );

        
    }
 
    /**
     * @notice Liquidates a defaulted loan using a reverse auction that starts high and falls to zero.
     * @dev The amount of tokens withdrawn from the liquidator is always the sum of _tokenAmountDifference + amountDue .
     * @dev Handles the liquidation process for a defaulted loan bid, ensuring all conditions for liquidation are met.
     * @param _bidId Identifier for the defaulted loan bid.
     * @param _tokenAmountDifference The incentive difference in tokens required for liquidation. Positive values indicate extra tokens to take, and negative values indicate extra tokens to give.
     */
    function liquidateDefaultedLoanWithIncentive(
        uint256 _bidId,
        int256 _tokenAmountDifference
    ) external whenForwarderNotPaused whenLiquidationAuctionNotPaused whenNotPaused bidIsActiveForGroup(_bidId) nonReentrant onlyOracleApprovedAllowEOA {
        


        uint256 loanTotalPrincipalAmount = _getLoanTotalPrincipalAmount(_bidId);  //only used for the auction delta amount 
        
        (uint256 principalDue,uint256 interestDue) = _getAmountOwedForBid(_bidId);  //this is the base amount that must be repaid by the liquidator
                

        uint256 loanDefaultedTimeStamp = ITellerV2(TELLER_V2)
            .getLoanDefaultTimestamp(_bidId);

        uint256 loanDefaultedOrUnpausedAtTimeStamp = Math.max(
            loanDefaultedTimeStamp,
            getLastUnpausedAt()
        );

        int256 minAmountDifference = getMinimumAmountDifferenceToCloseDefaultedLoan(
                loanTotalPrincipalAmount,
                loanDefaultedOrUnpausedAtTimeStamp
            );
 
 
        require(
            _tokenAmountDifference >= minAmountDifference,
            "TAD"
        );


        if (minAmountDifference > 0) {
            //this is used when the collateral value is higher than the principal (rare)
            //the loan will be completely made whole and our contract gets extra funds too
            uint256 tokensToTakeFromSender = abs(minAmountDifference);
            
           
        
           uint256 liquidationProtocolFee = Math.mulDiv( 
                tokensToTakeFromSender , 
                ISmartCommitmentForwarder(SMART_COMMITMENT_FORWARDER)
                    .getLiquidationProtocolFeePercent(),
                 10000)  ;
           

            IERC20(principalToken).safeTransferFrom(
                msg.sender,
                address(this),
                principalDue + tokensToTakeFromSender - liquidationProtocolFee
            ); 
             
            address protocolFeeRecipient = ITellerV2(address(TELLER_V2)).getProtocolFeeRecipient();

            if (liquidationProtocolFee > 0) {
                IERC20(principalToken).safeTransferFrom(
                    msg.sender,
                    address(protocolFeeRecipient),
                    liquidationProtocolFee
                );
            }

            totalPrincipalTokensRepaid += principalDue;

         
            tokenDifferenceFromLiquidations += int256(tokensToTakeFromSender - liquidationProtocolFee );


        } else {
          
           
            uint256 tokensToGiveToSender = abs(minAmountDifference);

             
        
            //dont stipend/refund more than principalDue base 
            if (tokensToGiveToSender > principalDue) {
                tokensToGiveToSender = principalDue;
            }

            uint256 netAmountDue =   principalDue - tokensToGiveToSender ;
 

            if (netAmountDue > 0) {
                IERC20(principalToken).safeTransferFrom(
                    msg.sender,
                    address(this),
                    netAmountDue //principalDue - tokensToGiveToSender  
                );
            }

            totalPrincipalTokensRepaid += principalDue;

            tokenDifferenceFromLiquidations -= int256(tokensToGiveToSender);
 

           
        }

        //this will effectively 'forfeit' tokens from this contract equal to the amount (principal) that has not been repaid ! principalDue
        //this will give collateral to the caller
        ITellerV2(TELLER_V2).lenderCloseLoanWithRecipient(_bidId, msg.sender);
    
    
         emit DefaultedLoanLiquidated(
            _bidId,
            msg.sender,
            principalDue, 
            _tokenAmountDifference
        );
    }

       
    /**
     * @notice Returns the timestamp when the contract was last unpaused
     * @dev Compares the internal lastUnpausedAt timestamp with the timestamp from the SmartCommitmentForwarder
     * @dev This accounts for pauses from both this contract and the forwarder
     * @return The maximum timestamp between the contract's last unpause and the forwarder's last unpause
     */
    function getLastUnpausedAt() 
    public view 
    returns (uint256) {


        return Math.max(
            lastUnpausedAt,
            IPausableTimestamp(SMART_COMMITMENT_FORWARDER).getLastUnpausedAt() //this counts tellerV2 pausing
            )
        ;
 

    }


    /**
     * @notice Sets the lastUnpausedAt timestamp to the current block timestamp
     * @dev Called internally when the contract is unpaused
     * @dev This timestamp is used to calculate valid liquidation windows after unpausing
     */
    function setLastUnpausedAt() internal {
        lastUnpausedAt =  block.timestamp;
    }


    /**
     * @notice Gets the total principal amount of a loan
     * @dev Retrieves loan details from the TellerV2 contract
     * @param _bidId The unique identifier of the loan bid
     * @return principalAmount The total principal amount of the loan
     */
     function _getLoanTotalPrincipalAmount(uint256 _bidId )
        internal
        view
        virtual
        returns (uint256 principalAmount)
    {
        (,,,, principalAmount, , ,  )
           = ITellerV2(TELLER_V2).getLoanSummary(_bidId);

       
    }

        

    /**
     * @notice Calculates the amount currently owed for a specific bid
     * @dev Calls the TellerV2 contract to calculate the principal and interest due
     * @dev Uses the current block.timestamp to calculate up-to-date amounts
     * @param _bidId The unique identifier of the loan bid
     * @return principal The principal amount currently owed
     * @return interest The interest amount currently owed
     */
    function _getAmountOwedForBid(uint256 _bidId )
        internal
        view
        virtual
        returns (uint256 principal,uint256 interest)
    {
        Payment memory owed = ITellerV2(TELLER_V2).calculateAmountOwed(_bidId, block.timestamp );

        return (owed.principal, owed.interest) ;
    }


    /**
     * @notice Returns the cumulative token difference from all liquidations
     * @dev This represents the net gain or loss of principal tokens from liquidation events
     * @dev Positive values indicate the pool has gained tokens from liquidations
     * @dev Negative values indicate the pool has given out tokens as liquidation incentives
     * @return The current token difference from all liquidations as a signed integer
     */
    function getTokenDifferenceFromLiquidations() public view returns (int256){

        return tokenDifferenceFromLiquidations;

    }
    

    /*
       * @dev This function will calculate the incentive amount (using a uniswap bonus plus a timer)
             of principal tokens that will be given to incentivize liquidating a loan 

       * @dev As time approaches infinite, the output approaches -1 * AmountDue .  
    */
    function getMinimumAmountDifferenceToCloseDefaultedLoan(
        uint256 _amountOwed,
        uint256 _loanDefaultedTimestamp
    ) public view virtual returns (int256 amountDifference_) {
        
        require(
           _loanDefaultedTimestamp > 0 &&  block.timestamp > _loanDefaultedTimestamp,
            "LDT"
        );

        uint256 secondsSinceDefaulted = block.timestamp -
            _loanDefaultedTimestamp;

        //this starts at 764% and falls to -100% 
        int256 incentiveMultiplier = int256(86400 - 10000) -
            int256(secondsSinceDefaulted);

        if (incentiveMultiplier < -10000) {
            incentiveMultiplier = -10000;
        }

        amountDifference_ =
            (int256(_amountOwed) * incentiveMultiplier) /
            int256(10000);
    }

    /**
     * @notice Calculates the absolute value of an integer
     * @dev Utility function to convert a signed integer to its unsigned absolute value
     * @param x The signed integer input
     * @return The absolute value of x as an unsigned integer
     */
    function abs(int x) private pure returns (uint) {
        return x >= 0 ? uint(x) : uint(-x);
    }


    function calculateCollateralRequiredToBorrowPrincipal(  
        uint256 _principalAmount
    ) public
        view
        virtual
        returns (uint256) {

        uint256 baseAmount = calculateCollateralTokensAmountEquivalentToPrincipalTokens(
                _principalAmount
        ); 

        //this is an amount of collateral
        return baseAmount.percent(collateralRatio);
    }

    /* 
    * @dev this is expanded by 10e18
    * @dev this logic is very similar to that used in LCFA 
    */
    function calculateCollateralTokensAmountEquivalentToPrincipalTokens(
        uint256 principalAmount 
    ) public view virtual returns (uint256 collateralTokensAmountToMatchValue) {
   
        uint256 pairPriceWithTwapFromOracle = UniswapPricingLibraryV2
            .getUniswapPriceRatioForPoolRoutes(poolOracleRoutes);
       
       
        uint256 principalPerCollateralAmount = maxPrincipalPerCollateralAmount == 0  
                ? pairPriceWithTwapFromOracle   
                : Math.min(
                    pairPriceWithTwapFromOracle,
                    maxPrincipalPerCollateralAmount //this is expanded by uniswap exp factor  
                );


        return
            getRequiredCollateral(
                principalAmount,
                principalPerCollateralAmount   
            );
    }


   /**
     * @notice Retrieves the price ratio from Uniswap for the given pool routes
     * @dev Calls the UniswapPricingLibraryV2 to get TWAP (Time-Weighted Average Price) for the specified routes
     * @dev This is a low-level internal function that handles direct Uniswap oracle interaction
     * @param poolOracleRoutes Array of pool route configurations to use for price calculation
     * @return The Uniswap price ratio expanded by the Uniswap expansion factor (2^96)
     */
    function getUniswapPriceRatioForPoolRoutes(
       IUniswapPricingLibrary.PoolRouteConfig[] memory poolOracleRoutes
    ) internal  view virtual returns (uint256 ) {
   
        uint256 pairPriceWithTwapFromOracle = UniswapPricingLibraryV2
            .getUniswapPriceRatioForPoolRoutes(poolOracleRoutes);
       

        return pairPriceWithTwapFromOracle;
    }

    /**
     * @notice Calculates the principal token amount per collateral token based on Uniswap oracle prices
     * @dev Uses Uniswap TWAP and applies any configured maximum limits
     * @dev Returns the lesser of the oracle price or the configured maximum (if set)
     * @param poolOracleRoutes Array of pool route configurations to use for price calculation
     * @return The principal per collateral ratio, expanded by the Uniswap expansion factor
     */
    function getPrincipalForCollateralForPoolRoutes(
        IUniswapPricingLibrary.PoolRouteConfig[] memory poolOracleRoutes
    ) external view virtual returns (uint256 ) {
   
        uint256 pairPriceWithTwapFromOracle = UniswapPricingLibraryV2
            .getUniswapPriceRatioForPoolRoutes(poolOracleRoutes);
       
       
        uint256 principalPerCollateralAmount = maxPrincipalPerCollateralAmount == 0  
                ? pairPriceWithTwapFromOracle   
                : Math.min(
                    pairPriceWithTwapFromOracle,
                    maxPrincipalPerCollateralAmount //this is expanded by uniswap exp factor  
                );


        return principalPerCollateralAmount;
    } 


    /**
     * @notice Calculates the amount of collateral tokens required for a given principal amount
     * @dev Converts principal amount to equivalent collateral based on current price ratio
     * @dev Uses the Math.mulDiv function with rounding up to ensure sufficient collateral
     * @param _principalAmount The amount of principal tokens to be borrowed
     * @param _maxPrincipalPerCollateralAmount The exchange rate between principal and collateral (expanded by STANDARD_EXPANSION_FACTOR)
     * @return The required amount of collateral tokens, rounded up to ensure sufficient collateralization
     */
   function getRequiredCollateral(
        uint256 _principalAmount,
        uint256 _maxPrincipalPerCollateralAmount 
        
    ) internal  view virtual returns (uint256) {
         
         return
            MathUpgradeable.mulDiv(
                _principalAmount,
                STANDARD_EXPANSION_FACTOR,
                _maxPrincipalPerCollateralAmount,
                MathUpgradeable.Rounding.Up
            );  
    }
 

    /*
        @dev This callback occurs when a TellerV2 repayment happens or when a TellerV2 liquidate happens 
        @dev lenderCloseLoan does not trigger a repayLoanCallback 
        @dev It is important that only teller loans for this specific pool can call this
        @dev It is important that this function does not revert even if paused since repayments can occur in this case
    */
    function repayLoanCallback(
        uint256 _bidId,
        address repayer,
        uint256 principalAmount,
        uint256 interestAmount
    ) external onlyTellerV2 bidIsActiveForGroup(_bidId) { 

        uint256 amountDueRemaining = activeBidsAmountDueRemaining[_bidId];

        
        uint256 principalAmountAppliedToAmountDueRemaining = principalAmount <  amountDueRemaining ? 
            principalAmount : amountDueRemaining; 


        //should never fail due to the above .
        activeBidsAmountDueRemaining[_bidId] -= principalAmountAppliedToAmountDueRemaining; 
 

        totalPrincipalTokensRepaid += principalAmountAppliedToAmountDueRemaining;
        totalInterestCollected += interestAmount;


        uint256 excessiveRepaymentAmount = principalAmount <  amountDueRemaining ? 
            0 : (principalAmount - amountDueRemaining);  
 
        excessivePrincipalTokensRepaid += excessiveRepaymentAmount; 


         emit LoanRepaid(
            _bidId,
            repayer,
            principalAmount,
            interestAmount,
            totalPrincipalTokensRepaid,
            totalInterestCollected
        );
    }


 


    /**
     * @notice If principal get stuck in the escrow vault for any reason, anyone may
     *   call this function to move them from that vault in to this contract 
     * @param _amount  Amount of tokens to withdraw
     */
    function withdrawFromEscrowVault ( uint256 _amount ) external whenForwarderNotPaused whenNotPaused {

        address _escrowVault = ITellerV2(TELLER_V2).getEscrowVault();

        IEscrowVault(_escrowVault).withdraw(address(principalToken), _amount );  

        emit WithdrawFromEscrow(_amount);

    }
 




    /**
     * @notice Sets an optional manual ratio for principal/collateral ratio for borrowers. Only Pool Owner.
     * @param _maxPrincipalPerCollateralAmount Price ratio, expanded to support sub-one ratios.
     */
    function setMaxPrincipalPerCollateralAmount(uint256 _maxPrincipalPerCollateralAmount) 
    external 
    onlyOwner {
       maxPrincipalPerCollateralAmount = _maxPrincipalPerCollateralAmount;
    }

  


    /**
     * @notice This determines the number of shares you get for depositing principal tokens and the number of principal tokens you receive for burning shares
     * @return rate_ The current exchange rate, scaled by the EXCHANGE_RATE_FACTOR.
     */

    function sharesExchangeRate() public view virtual returns (uint256 rate_) {
        

        uint256 poolTotalEstimatedValue = getPoolTotalEstimatedValue();

        if (totalSupply() == 0) {
            return EXCHANGE_RATE_EXPANSION_FACTOR; // 1 to 1 for first swap
        }

        rate_ =
            MathUpgradeable.mulDiv(poolTotalEstimatedValue , 
                EXCHANGE_RATE_EXPANSION_FACTOR ,
                  totalSupply() );
    }

    function sharesExchangeRateInverse()
        public
        view
        virtual
        returns (uint256 rate_)
    {
        return
            (EXCHANGE_RATE_EXPANSION_FACTOR * EXCHANGE_RATE_EXPANSION_FACTOR) /
            sharesExchangeRate();
    }

    function getPoolTotalEstimatedValue()
        internal 
        view
        returns (uint256 poolTotalEstimatedValue_)
    {
       
         int256 poolTotalEstimatedValueSigned = int256(totalPrincipalTokensCommitted) 
                  
         + int256(totalInterestCollected)  + int256(tokenDifferenceFromLiquidations) 
         + int256( excessivePrincipalTokensRepaid )
         - int256( totalPrincipalTokensWithdrawn )
         
         ;



        //if the poolTotalEstimatedValue_ is less than 0, we treat it as 0.  
        poolTotalEstimatedValue_ = poolTotalEstimatedValueSigned > int256(0)
            ? uint256(poolTotalEstimatedValueSigned)
            : 0;
    }

    /**
     * @notice Converts an amount to its underlying value using a given exchange rate with rounding down
     * @dev Uses MathUpgradeable.mulDiv with explicit rounding down to prevent favorable rounding for users
     * @dev This function is used for conversions where rounding down protects the protocol (e.g., calculating shares to mint)
     * @param amount The amount to convert (in the source unit)
     * @param rate The exchange rate to apply, expanded by EXCHANGE_RATE_EXPANSION_FACTOR
     * @return value_ The converted value in the target unit, rounded down
     */
    function _valueOfUnderlying(uint256 amount, uint256 rate)
        internal
        pure
        returns (uint256 value_)
    {
        if (rate == 0) {
            return 0;
        }

         // value_ = MathUpgradeable.mulDiv(amount ,  EXCHANGE_RATE_EXPANSION_FACTOR   ,  rate );

         value_ = MathUpgradeable.mulDiv(
                amount, 
                EXCHANGE_RATE_EXPANSION_FACTOR, 
                rate,
                MathUpgradeable.Rounding.Down  // Explicitly round down
            );


    }


    /**
     * @notice Converts an amount to its underlying value using a given exchange rate with rounding up
     * @dev Uses MathUpgradeable.mulDiv with explicit rounding up to ensure protocol safety
     * @dev This function is used for conversions where rounding up protects the protocol (e.g., calculating assets needed for shares)
     * @param amount The amount to convert (in the source unit)
     * @param rate The exchange rate to apply, expanded by EXCHANGE_RATE_EXPANSION_FACTOR
     * @return value_ The converted value in the target unit, rounded up
     */
    function _valueOfUnderlyingRoundUpwards(uint256 amount, uint256 rate)
        internal
        pure
        returns (uint256 value_)
    {
        if (rate == 0) {
            return 0;
        }

     
         value_ = MathUpgradeable.mulDiv(
                amount, 
                EXCHANGE_RATE_EXPANSION_FACTOR, 
                rate,
                MathUpgradeable.Rounding.Up  // Explicitly round down
            ); 

    }




    /**
     * @notice Calculates the total amount of principal tokens currently lent out in active loans
     * @dev Subtracts the total repaid principal from the total lent principal
     * @dev Returns 0 if repayments exceed lending (which should not happen in normal operation)
     * @return The net amount of principal tokens currently outstanding in active loans
     */
    function getTotalPrincipalTokensOutstandingInActiveLoans()
        internal 
        view
        returns (uint256)
    {   
        if (totalPrincipalTokensRepaid > totalPrincipalTokensLended) {
            return 0;
        }

        return totalPrincipalTokensLended - totalPrincipalTokensRepaid;
    }



    /**
     * @notice Returns the address of the collateral token accepted by this pool
     * @dev Implements the ISmartCommitment interface requirement
     * @dev This is used by the SmartCommitmentForwarder to verify collateral compatibility
     * @return The address of the ERC20 token used as collateral in this pool
     */
    function getCollateralTokenAddress() external view returns (address) {
        return address(collateralToken);
    }   



    /**
     * @notice Returns the token ID for ERC721/ERC1155 collateral
     * @dev Always returns 0 for this implementation as it only supports ERC20 tokens
     * @dev Implements the ISmartCommitment interface requirement
     * @return Always returns 0, as ERC20 tokens don't have token IDs
     */
    function getCollateralTokenId() external view returns (uint256) {
        return 0;
    }

    /**
     * @notice Returns the type of collateral token supported by this pool
     * @dev Implements the ISmartCommitment interface requirement
     * @dev This pool only supports ERC20 tokens as collateral
     * @return The collateral token type (ERC20) from the CommitmentCollateralType enum
     */
    function getCollateralTokenType()
        external
        view
        returns (CommitmentCollateralType)
    {
        return CommitmentCollateralType.ERC20;
    }
 
    /**
     * @notice Returns the Teller V2 market ID associated with this lending pool
     * @dev Implements the ISmartCommitment interface requirement
     * @dev The market ID is set during contract initialization and cannot be changed
     * @return The unique market ID within the Teller V2 protocol
     */
    function getMarketId() external view returns (uint256) {
        return marketId;
    }

    /**
     * @notice Returns the maximum allowed duration for loans in this pool
     * @dev Implements the ISmartCommitment interface requirement
     * @dev This value is set during contract initialization and represents seconds
     * @dev Borrowers cannot request loans with durations exceeding this value
     * @return The maximum loan duration in seconds
     */
    function getMaxLoanDuration() external view returns (uint32) {
        return maxLoanDuration;
    }

    /**
     * @notice Calculates the current utilization ratio of the pool
     * @dev The utilization ratio is the percentage of committed funds currently out on loans
     * @dev Formula: (outstandingLoans + activeLoansAmountDelta) / poolTotalEstimatedValue * 10000
     * @dev Result is capped at 10000 (100%)
     * @param activeLoansAmountDelta Additional loan amount to consider for utilization calculation
     * @return The utilization ratio as a percentage with 2 decimal precision (e.g., 7500 = 75.00%)
     */
    function getPoolUtilizationRatio(uint256 activeLoansAmountDelta ) public view returns (uint16) {

        if (getPoolTotalEstimatedValue() == 0) {
            return 0;
        }

        return uint16(  Math.min(                          
                            MathUpgradeable.mulDiv( 
                                (getTotalPrincipalTokensOutstandingInActiveLoans() + activeLoansAmountDelta), 
                                10000  ,
                                getPoolTotalEstimatedValue() ) , 
                        10000  ));

    }
    /**
     * @notice Calculates the minimum interest rate based on current pool utilization
     * @dev The interest rate scales linearly between lower and upper bounds based on utilization
     * @dev Formula: lowerBound + (upperBound - lowerBound) * utilizationRatio
     * @dev Higher utilization results in higher interest rates to incentivize repayments
     * @param amountDelta Additional amount to consider when calculating utilization for this rate
     * @return The minimum interest rate as a percentage with 2 decimal precision (e.g., 500 = 5.00%)
     */
    function getMinInterestRate(uint256 amountDelta) public view returns (uint16) {
        return interestRateLowerBound + 
        uint16( uint256(interestRateUpperBound-interestRateLowerBound)
        .percent(getPoolUtilizationRatio(amountDelta )
        
        ) );
    } 
    

    /**
     * @notice Returns the address of the principal token used by this pool
     * @dev Implements the ISmartCommitment interface requirement
     * @dev The principal token is the asset that lenders deposit and borrowers borrow
     * @return The address of the ERC20 token used as principal in this pool
     */
    function getPrincipalTokenAddress() external view returns (address) {
        return address(principalToken);
    }

   
    /**
     * @notice Calculates the amount of principal tokens available for new loans
     * @dev The available amount is limited by the liquidity threshold percentage of the pool
     * @dev Formula: min(poolValueThreshold - outstandingLoans, 0)
     * @dev The pool won't allow borrowing beyond the configured threshold to maintain liquidity for withdrawals
     * @return The amount of principal tokens available for new loans, returns 0 if threshold is reached
     */
    function getPrincipalAmountAvailableToBorrow()
        public
        view
        returns (uint256)
    {     


         // Calculate the threshold value once to avoid duplicate calculations
        uint256 poolValueThreshold = uint256(getPoolTotalEstimatedValue()).percent(liquidityThresholdPercent);
        
        // Get the outstanding loan amount
        uint256 outstandingLoans = getTotalPrincipalTokensOutstandingInActiveLoans();
        
        // If outstanding loans exceed or equal the threshold, return 0
        if (poolValueThreshold <= outstandingLoans) {
            return 0;
        }
            
            // Return the difference between threshold and outstanding loans
            return poolValueThreshold - outstandingLoans;

      
     
    }



    /**
     * @notice Sets the delay time for withdrawing shares. Only Protocol Owner.
     * @param _seconds Delay time in seconds.
     */
    function setWithdrawDelayTime(uint256 _seconds) 
    external 
    onlyProtocolOwner {
        require( _seconds < MAX_WITHDRAW_DELAY_TIME , "min withdraw delay");

        withdrawDelayTimeSeconds = _seconds;
    }



    // ------------------------   Pausing functions  ------------ 



    event Paused(address account);
    event Unpaused(address account);

    event PausedBorrowing(address account);
    event UnpausedBorrowing(address account);

    event PausedLiquidationAuction(address account);
    event UnpausedLiquidationAuction(address account);


    modifier whenPaused() {
        require(paused, "Must be paused");
        _;
    }
    modifier whenNotPaused() {
        require(!paused, "Must not be paused");
        _;
    }

    modifier whenBorrowingPaused() {
        require(borrowingPaused, "Must be paused");
        _;
    }
    modifier whenBorrowingNotPaused() {
        require(!borrowingPaused, "Must not be paused");
        _;
    }

    modifier whenLiquidationAuctionPaused() {
        require(liquidationAuctionPaused, "Must be paused");
        _;
    }
    modifier whenLiquidationAuctionNotPaused() {
        require(!liquidationAuctionPaused, "Must not be paused");
        _;
    }



    function _pause() internal {
        paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal {
        paused = false;
        emit Unpaused(_msgSender());
    }


    function _pauseBorrowing() internal {
        borrowingPaused = true;
        emit PausedBorrowing(_msgSender());
    }

    function _unpauseBorrowing() internal {
        borrowingPaused = false;
        emit UnpausedBorrowing(_msgSender());
    }


    function _pauseLiquidationAuction() internal {
        liquidationAuctionPaused = true;
        emit PausedLiquidationAuction(_msgSender());
    }

    function _unpauseLiquidationAuction() internal {
        liquidationAuctionPaused = false;
        emit UnpausedLiquidationAuction(_msgSender());
    }




    /**
     * @notice Lets the DAO/owner of the protocol pause borrowing
     */
    function pauseBorrowing() public virtual onlyProtocolPauser whenBorrowingNotPaused {
        _pauseBorrowing();
    }

    /**
     * @notice Lets the DAO/owner of the protocol unpause borrowing
     */
    function unpauseBorrowing() public virtual onlyProtocolPauser whenBorrowingPaused {
        //setLastUnpausedAt();  // dont need this, can still liq when borrowing is paused 
        _unpauseBorrowing();
    }

    /**
     * @notice Lets the DAO/owner of the protocol pause liquidation auctions
     */
    function pauseLiquidationAuction() public virtual onlyProtocolPauser whenLiquidationAuctionNotPaused {
        _pauseLiquidationAuction();
    }

    /**
     * @notice Lets the DAO/owner of the protocol unpause liquidation auctions
     */
    function unpauseLiquidationAuction() public virtual onlyProtocolPauser whenLiquidationAuctionPaused {
        setLastUnpausedAt();   
        _unpauseLiquidationAuction();
    }



    /**
     * @notice Lets the DAO/owner of the protocol implement an emergency stop mechanism.
     */
    function pausePool() public virtual onlyProtocolPauser whenNotPaused {
        _pause();
    }

    /**
     * @notice Lets the DAO/owner of the protocol undo a previously implemented emergency stop.
     */
    function unpausePool() public virtual onlyProtocolPauser whenPaused {
        setLastUnpausedAt();
        _unpause();
    }




    // ------------------------   ERC4626  functions  ------------ 



 



    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    
    function deposit(uint256 assets, address receiver) 
    public 
    whenForwarderNotPaused whenNotPaused nonReentrant onlyOracleApprovedAllowEOA 
    virtual 
    returns (uint256 shares) {

        // Similar to addPrincipalToCommitmentGroup but following ERC4626 standard
        require(assets > 0, "no assets" );
        
       
        
        // Transfer assets from sender to vault
        uint256 principalTokenBalanceBefore = principalToken.balanceOf(address(this));
        principalToken.safeTransferFrom(msg.sender, address(this), assets);
        uint256 principalTokenBalanceAfter = principalToken.balanceOf(address(this));
        require(principalTokenBalanceAfter == principalTokenBalanceBefore + assets, "TB");


         // Calculate shares after transfer
        shares = _valueOfUnderlying(assets, sharesExchangeRate());

        
        // Update totals
        totalPrincipalTokensCommitted += assets;
        
        // Mint shares to receiver
        mintShares(receiver, shares);
        
        // Check first deposit conditions
        if(!firstDepositMade){
            require(msg.sender == owner(), "FDM");
            require(shares >= 1e6, "IS");
            firstDepositMade = true;
        }
        
       // emit LenderAddedPrincipal(msg.sender, assets, shares, receiver);
        emit Deposit( msg.sender,receiver, assets, shares );

        return shares;
    }

    
    function mint(uint256 shares, address receiver) 
    public 
    whenForwarderNotPaused whenNotPaused nonReentrant onlyOracleApprovedAllowEOA 
    virtual 
    returns (uint256 assets) {

        // Calculate assets needed for desired shares
        assets = previewMint(shares);
        require(assets > 0 , "no assets");


        
        // Transfer assets from sender to vault
        uint256 principalTokenBalanceBefore = principalToken.balanceOf(address(this));
        principalToken.safeTransferFrom(msg.sender, address(this), assets);
        uint256 principalTokenBalanceAfter = principalToken.balanceOf(address(this));
        require(principalTokenBalanceAfter == principalTokenBalanceBefore + assets, "TB");
        
        // Update totals
        totalPrincipalTokensCommitted += assets;
        
        // Mint shares to receiver
        mintShares(receiver, shares);
        
        // Check first deposit conditions
        if(!firstDepositMade){
            require(msg.sender == owner(), "IC");
            require(shares >= 1e6, "IS");
            firstDepositMade = true;
        }
        
       
        emit Deposit( msg.sender,receiver, assets, shares );
        return assets;
    }

   
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public 
    whenForwarderNotPaused whenNotPaused  nonReentrant onlyOracleApprovedAllowEOA 
    virtual 
    returns (uint256 shares) {
        
        // Calculate shares required for desired assets
        shares = previewWithdraw(assets);
        require(shares > 0, "S");
         
        
        // Check withdrawal delay
        uint256 sharesLastTransferredAt = getSharesLastTransferredAt(owner);
        require(block.timestamp >= sharesLastTransferredAt + withdrawDelayTimeSeconds, "SW");

        require(msg.sender == owner, "UA");
        
        // Burn shares from owner
        burnShares(owner, shares);
        
        // Update totals
        totalPrincipalTokensWithdrawn += assets;
        
        // Transfer assets to receiver
        principalToken.safeTransfer(receiver, assets);
        
        
        emit Withdraw(
                owner,
                receiver,
                owner,
                assets,
                shares
            );

        return shares;
    }   

    
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public 
    whenForwarderNotPaused whenNotPaused  nonReentrant onlyOracleApprovedAllowEOA 
    virtual 
    returns (uint256 assets) {

        // Similar to burnSharesToWithdrawEarnings but following ERC4626 standard
        require(shares > 0, "S");
        
        // Calculate assets to receive
        assets = _valueOfUnderlying(shares, sharesExchangeRateInverse());
     
        require(msg.sender == owner, "UA");

        // Check withdrawal delay
        uint256 sharesLastTransferredAt = getSharesLastTransferredAt(owner);
        require(block.timestamp >= sharesLastTransferredAt + withdrawDelayTimeSeconds, "SR");
        
        // Burn shares from owner
        burnShares(owner, shares);
        
        // Update totals
        totalPrincipalTokensWithdrawn += assets;
        
        // Transfer assets to receiver
        principalToken.safeTransfer(receiver, assets);
        
        emit Withdraw(
                owner,
                receiver,
                owner,
                assets,
                shares
            );

        return assets;
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function totalAssets() public view virtual returns (uint256) {
        return getPoolTotalEstimatedValue();
    }

 
 
   
    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        return _valueOfUnderlying(assets, sharesExchangeRate());
    } 

    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        return _valueOfUnderlying(shares, sharesExchangeRateInverse());
    }

     
    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
      
         return _valueOfUnderlying(assets, sharesExchangeRate());
    }

 
    function previewMint(uint256 shares) public view virtual returns (uint256) {
        
        
         return _valueOfUnderlyingRoundUpwards(shares, sharesExchangeRateInverse());
      
     
    }

  
    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        
          
         return _valueOfUnderlyingRoundUpwards( assets, sharesExchangeRate() ) ;
      
    }

 
    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
          
         return _valueOfUnderlying(shares, sharesExchangeRateInverse());    
       
    }

    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function maxDeposit(address) public view virtual returns (uint256) {
        if (paused) {
            return 0;
        }

        if(!firstDepositMade && msg.sender != owner()){
           return 0;
        }


        return type(uint256).max;
    }

    function maxMint(address) public view virtual returns (uint256) {
        if (paused) {
            return 0;
        }

        if(!firstDepositMade && msg.sender != owner()){
           return 0;
        }
        
        return type(uint256).max;
    }

    
    function maxWithdraw(address owner) public view virtual returns (uint256) {
        if (paused) {
            return 0;
        }
        
        uint256 ownerAssets = convertToAssets(balanceOf(owner));
        uint256 availableLiquidity = principalToken.balanceOf(address(this));
        
        return Math.min(ownerAssets, availableLiquidity);
    }

     
    function maxRedeem(address owner) public view virtual returns (uint256) {
        if (paused) {
            return 0;
        }
        
        uint256 availableShares = balanceOf(owner);
        uint256 sharesLastTransferredAt = getSharesLastTransferredAt(owner);
        
        if (block.timestamp <= sharesLastTransferredAt + withdrawDelayTimeSeconds) {
            return 0;
        }
        
        uint256 availableLiquidity = principalToken.balanceOf(address(this));
        uint256 maxSharesBasedOnLiquidity = convertToShares(availableLiquidity);
        
        return Math.min(availableShares, maxSharesBasedOnLiquidity);
    }

 
     function asset() public view returns (address assetTokenAddress) {

        return address(principalToken) ; 
    }




} 