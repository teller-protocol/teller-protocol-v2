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

//import "../../../interfaces/IFlashRolloverLoan.sol";
import "../../../libraries/NumbersLib.sol";

import "../../../interfaces/uniswap/IUniswapV3Pool.sol";

import "../../../interfaces/uniswap/IUniswapV3Factory.sol";
import "../../../interfaces/ISmartCommitmentForwarder.sol";

import "../../../libraries/uniswap/TickMath.sol";
import "../../../libraries/uniswap/FixedPoint96.sol";
import "../../../libraries/uniswap/FullMath.sol";

import {LenderCommitmentGroupShares} from "./LenderCommitmentGroupShares.sol";

import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import { CommitmentCollateralType, ISmartCommitment } from "../../../interfaces/ISmartCommitment.sol";
import { ILoanRepaymentListener } from "../../../interfaces/ILoanRepaymentListener.sol";

import { ILoanRepaymentCallbacks } from "../../../interfaces/ILoanRepaymentCallbacks.sol";

import { IEscrowVault } from "../../../interfaces/IEscrowVault.sol";
import { ILenderCommitmentGroup } from "../../../interfaces/ILenderCommitmentGroup.sol";
import { Payment } from "../../../TellerV2Storage.sol";

import {IUniswapPricingLibrary} from "../../../interfaces/IUniswapPricingLibrary.sol";
import {UniswapPricingLibrary} from "../../../libraries/UniswapPricingLibrary.sol";


import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
/*
 

 Each LenderCommitmentGroup SmartContract acts as its own Loan Commitment (for the SmartCommitmentForwarder) and acts as its own Lender in the Teller Protocol.

 Lender Users can deposit principal tokens in this contract and this will give them Share Tokens (LP tokens) representing their ownership in the liquidity pool of this contract.

 Borrower Users can borrow principal token funds from this contract (via the SCF contract) by providing collateral tokens in the proper amount as specified by the rules of this smart contract.
 These collateral tokens are then owned by this smart contract and are returned to the borrower via the Teller Protocol rules to the borrower if and only if the borrower repays principal and interest of the loan they took.

 If the borrower defaults on a loan, for 24 hours a liquidation auction is automatically conducted by this smart contract in order to incentivize a liquidator to take the collateral tokens in exchange for principal tokens.

  
 

*/

contract LenderCommitmentGroup_Smart is
    ILenderCommitmentGroup,
    ISmartCommitment,
    ILoanRepaymentListener,
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable
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
    address private UNISWAP_V3_POOL; //deprecated
 
    LenderCommitmentGroupShares public poolSharesToken;

    IERC20 public principalToken;
    IERC20 public collateralToken;
    uint24 private _uniswapPoolFee; //deprecated

    uint256 marketId;

 
    uint256 public totalPrincipalTokensCommitted; 
    uint256 public totalPrincipalTokensWithdrawn;

    uint256 public totalPrincipalTokensLended;
    uint256 public totalPrincipalTokensRepaid; //subtract this and the above to find total principal tokens outstanding for loans

    
 
    uint256 public totalInterestCollected;

    uint16 public liquidityThresholdPercent; //5000 is 50 pct  // enforce max of 10000
    uint16 public collateralRatio; //the overcollateralization ratio, typically 80 pct

    uint32 private _twapInterval; //deprecated
    uint32 public maxLoanDuration;
    uint16 public interestRateLowerBound;
    uint16 public interestRateUpperBound;




    mapping(address => uint256) public poolSharesPreparedToWithdrawForLender;
    mapping(address => uint256) public poolSharesPreparedTimestamp;
    uint256 immutable public DEFAULT_WITHDRAWL_DELAY_TIME_SECONDS = 300;
    uint256 immutable public MAX_WITHDRAWL_DELAY_TIME = 86400;

    //mapping(address => uint256) public principalTokensCommittedByLender;
    mapping(uint256 => bool) public activeBids;

    //this excludes interest
    // maybe it is possible to get rid of this storage slot and calculate it from totalPrincipalTokensRepaid, totalPrincipalTokensLended
    int256 tokenDifferenceFromLiquidations;

    bool public firstDepositMade;
    uint256 public withdrawlDelayTimeSeconds; 

    IUniswapPricingLibrary.PoolRouteConfig[]  public  poolOracleRoutes ;

    //configured by the owner. If 0 , not used. 
    uint256 public maxPrincipalPerCollateralAmount; 
   

    event PoolInitialized(
        address indexed principalTokenAddress,
        address indexed collateralTokenAddress,
        uint256 marketId,
        uint32 maxLoanDuration,
        uint16 interestRateLowerBound,
        uint16 interestRateUpperBound,
        uint16 liquidityThresholdPercent,
        uint16 loanToValuePercent,
      //  uint24 uniswapPoolFee,
      //  uint32 twapInterval,
        address poolSharesToken
    );

    event LenderAddedPrincipal(
        address indexed lender,
        uint256 amount,
        uint256 sharesAmount,
        address indexed sharesRecipient
    );

    event BorrowerAcceptedFunds(
        address indexed borrower,
        uint256 indexed bidId,
        uint256 principalAmount,
        uint256 collateralAmount,
        uint32 loanDuration,
        uint16 interestRate
    );

    event EarningsWithdrawn(
        address indexed lender,
        uint256 amountPoolSharesTokens,
        uint256 principalTokensWithdrawn,
        address indexed recipient
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

    event PoolSharesPrepared(
        address lender,
        uint256 sharesAmount,
        uint256 preparedAt

    );


    modifier onlySmartCommitmentForwarder() {
        require(
            msg.sender == address(SMART_COMMITMENT_FORWARDER),
            "Can only be called by Smart Commitment Forwarder"
        );
        _;
    }

    modifier onlyTellerV2() {
        require(
            msg.sender == address(TELLER_V2),
            "Can only be called by TellerV2"
        );
        _;
    }


     modifier onlyProtocolOwner() {
        require(
            msg.sender == Ownable(address(TELLER_V2)).owner(),
            "Can only be called by TellerV2"
        );
        _;
    }

    modifier bidIsActiveForGroup(uint256 _bidId) {
        require(activeBids[_bidId] == true, "Bid is not active for group");

        _;
    }

    modifier whenForwarderNotPaused() {
         require( PausableUpgradeable(address(SMART_COMMITMENT_FORWARDER)).paused() == false , "Protocol is paused");
        _;
    }



    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _tellerV2,
        address _smartCommitmentForwarder,
        address _uniswapV3Factory
    ) {
        TELLER_V2 = _tellerV2;
        SMART_COMMITMENT_FORWARDER = _smartCommitmentForwarder;
        UNISWAP_V3_FACTORY = _uniswapV3Factory;
     
    }

    /*


        
    */
   function initialize(
       CommitmentGroupConfig calldata _commitmentGroupConfig,
       IUniswapPricingLibrary.PoolRouteConfig[] calldata _poolOracleRoutes
    ) external initializer returns (address poolSharesToken_) {
       
        __Ownable_init();
        __Pausable_init();

        principalToken = IERC20(_commitmentGroupConfig.principalTokenAddress);
        collateralToken = IERC20(_commitmentGroupConfig.collateralTokenAddress);
        /*uniswapPoolFee = _commitmentGroupConfig.uniswapPoolFee;

        UNISWAP_V3_POOL = IUniswapV3Factory(UNISWAP_V3_FACTORY).getPool(
            _commitmentGroupConfig.principalTokenAddress,
            _commitmentGroupConfig.collateralTokenAddress,
            _commitmentGroupConfig.uniswapPoolFee
        );*/

        //require(_commitmentGroupConfig.twapInterval >= MIN_TWAP_INTERVAL, "Invalid TWAP Interval");
        // require(UNISWAP_V3_POOL != address(0), "Invalid uniswap pool address");

        marketId = _commitmentGroupConfig.marketId;

        withdrawlDelayTimeSeconds = DEFAULT_WITHDRAWL_DELAY_TIME_SECONDS;

        //in order for this to succeed, first, that SmartCommitmentForwarder needs to be THE trusted forwarder for the market

         
        ITellerV2Context(TELLER_V2).approveMarketForwarder(
            _commitmentGroupConfig.marketId,
            SMART_COMMITMENT_FORWARDER
        );

        maxLoanDuration = _commitmentGroupConfig.maxLoanDuration;
        interestRateLowerBound = _commitmentGroupConfig.interestRateLowerBound;
        interestRateUpperBound = _commitmentGroupConfig.interestRateUpperBound;


        
        
        require(interestRateLowerBound <= interestRateUpperBound, "invalid _interestRateLowerBound");

       
        liquidityThresholdPercent = _commitmentGroupConfig.liquidityThresholdPercent;
        collateralRatio = _commitmentGroupConfig.collateralRatio;
        //twapInterval = _commitmentGroupConfig.twapInterval;

        require( liquidityThresholdPercent <= 10000, "invalid _liquidityThresholdPercent"); 

         

        for (uint256 i = 0; i < _poolOracleRoutes.length; i++) {
            poolOracleRoutes.push(_poolOracleRoutes[i]);
        }


         require(poolOracleRoutes.length >= 1 && poolOracleRoutes.length <= 2, "invalid pool routes length");
        
        poolSharesToken_ = _deployPoolSharesToken();


        emit PoolInitialized(
            _commitmentGroupConfig.principalTokenAddress,
            _commitmentGroupConfig.collateralTokenAddress,
            _commitmentGroupConfig.marketId,
            _commitmentGroupConfig.maxLoanDuration,
            _commitmentGroupConfig.interestRateLowerBound,
            _commitmentGroupConfig.interestRateUpperBound,
            _commitmentGroupConfig.liquidityThresholdPercent,
            _commitmentGroupConfig.collateralRatio,
            //_commitmentGroupConfig.uniswapPoolFee,
            //_commitmentGroupConfig.twapInterval,
            poolSharesToken_
        );
    }



    function setWithdrawlDelayTime(uint256 _seconds) 
    external 
    onlyProtocolOwner {

        require( _seconds < MAX_WITHDRAWL_DELAY_TIME );

        withdrawlDelayTimeSeconds = _seconds;
    }



    function setMaxPrincipalPerCollateralAmount(uint256 _maxPrincipalPerCollateralAmount) 
    external 
    onlyOwner {

       maxPrincipalPerCollateralAmount = _maxPrincipalPerCollateralAmount;
    }

    function _deployPoolSharesToken()
        internal
        onlyInitializing
        returns (address poolSharesToken_)
    {
      
        require(
            address(poolSharesToken) == address(0),
            "Pool shares already deployed"
        );
 
        poolSharesToken = new LenderCommitmentGroupShares(
            "LenderGroupShares",
            "SHR",
            18  
        );

        return address(poolSharesToken);
    } 


    /**
     * @notice This determines the number of shares you get for depositing principal tokens and the number of principal tokens you receive for burning shares
     * @return rate_ The current exchange rate, scaled by the EXCHANGE_RATE_FACTOR.
     */

    function sharesExchangeRate() public view virtual returns (uint256 rate_) {
        

        uint256 poolTotalEstimatedValue = getPoolTotalEstimatedValue();

        if (poolSharesToken.totalSupply() == 0) {
            return EXCHANGE_RATE_EXPANSION_FACTOR; // 1 to 1 for first swap
        }

        rate_ =
            MathUpgradeable.mulDiv(poolTotalEstimatedValue , 
                EXCHANGE_RATE_EXPANSION_FACTOR ,
                  poolSharesToken.totalSupply() );
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
        public
        view
        returns (uint256 poolTotalEstimatedValue_)
    {
       
         int256 poolTotalEstimatedValueSigned = int256(totalPrincipalTokensCommitted) 
         + int256(totalInterestCollected)  + int256(tokenDifferenceFromLiquidations) 
         - int256(totalPrincipalTokensWithdrawn);

        //if the poolTotalEstimatedValue_ is less than 0, we treat it as 0.  
        poolTotalEstimatedValue_ = poolTotalEstimatedValueSigned > int256(0)
            ? uint256(poolTotalEstimatedValueSigned)
            : 0;
    }

    /*
    must be initialized for this to work ! 
    */
    function addPrincipalToCommitmentGroup(
        uint256 _amount,
        address _sharesRecipient,
        uint256 _minSharesAmountOut
    ) external whenForwarderNotPaused returns (uint256 sharesAmount_) {
        //transfers the primary principal token from msg.sender into this contract escrow

       

        
 
        uint256 principalTokenBalanceBefore = principalToken.balanceOf(address(this));

        principalToken.safeTransferFrom(msg.sender, address(this), _amount);
 
        uint256 principalTokenBalanceAfter = principalToken.balanceOf(address(this));
 
        require( principalTokenBalanceAfter == principalTokenBalanceBefore + _amount, "Token balance was not added properly" );



        sharesAmount_ = _valueOfUnderlying(_amount, sharesExchangeRate());

        

        totalPrincipalTokensCommitted += _amount;
        

        //mint shares equal to _amount and give them to the shares recipient !!!
        poolSharesToken.mint(_sharesRecipient, sharesAmount_);
 
        

        // prepare current balance 
        uint256 sharesBalance = poolSharesToken.balanceOf(address(_sharesRecipient));
        _prepareSharesForWithdraw(_sharesRecipient,sharesBalance); 


        emit LenderAddedPrincipal( 

            msg.sender,
            _amount,
            sharesAmount_,
            _sharesRecipient

         );

        require( sharesAmount_ >= _minSharesAmountOut, "Invalid: Min Shares AmountOut" );
 
         if(!firstDepositMade){
            require(msg.sender == owner(), "Owner must initialize the pool with a deposit first.");
            require( sharesAmount_>= 1e6, "Initial shares amount must be atleast 1e6" );

            firstDepositMade = true;
        }
    }

    function _valueOfUnderlying(uint256 amount, uint256 rate)
        internal
        pure
        returns (uint256 value_)
    {
        if (rate == 0) {
            return 0;
        }

        value_ = MathUpgradeable.mulDiv(amount ,  EXCHANGE_RATE_EXPANSION_FACTOR   ,  rate ) ;
    }

    function acceptFundsForAcceptBid(
        address _borrower,
        uint256 _bidId,
        uint256 _principalAmount,
        uint256 _collateralAmount,
        address _collateralTokenAddress,
        uint256 _collateralTokenId, 
        uint32 _loanDuration,
        uint16 _interestRate
    ) external onlySmartCommitmentForwarder whenForwarderNotPaused {
        
        require(
            _collateralTokenAddress == address(collateralToken),
            "Mismatching collateral token"
        );
        //the interest rate must be at least as high has the commitment demands. The borrower can use a higher interest rate although that would not be beneficial to the borrower.
        require(_interestRate >= getMinInterestRate(_principalAmount), "Invalid interest rate");
        //the loan duration must be less than the commitment max loan duration. The lender who made the commitment expects the money to be returned before this window.
        require(_loanDuration <= maxLoanDuration, "Invalid loan max duration");

        require(
            getPrincipalAmountAvailableToBorrow() >= _principalAmount,
            "Invalid loan max principal"
        );
 
 
        uint256 requiredCollateral = calculateCollateralRequiredToBorrowPrincipal(
            _principalAmount
        );



        require(    
             _collateralAmount   >=
                requiredCollateral,
            "Insufficient Borrower Collateral"
        );
 
        principalToken.approve(address(TELLER_V2), _principalAmount);

        //do not have to spoof/forward as this contract is the lender !
        _acceptBidWithRepaymentListener(_bidId);

        totalPrincipalTokensLended += _principalAmount;

        activeBids[_bidId] = true; //bool for now
        

        emit BorrowerAcceptedFunds(  
            _borrower,
            _bidId,
            _principalAmount,
            _collateralAmount, 
            _loanDuration,
            _interestRate 
         );
    }

    function _acceptBidWithRepaymentListener(uint256 _bidId) internal {
        ITellerV2(TELLER_V2).lenderAcceptBid(_bidId); //this gives out the funds to the borrower

        ILoanRepaymentCallbacks(TELLER_V2).setRepaymentListenerForBid(
            _bidId,
            address(this)
        );

        
    }

    function prepareSharesForWithdraw(
        uint256 _amountPoolSharesTokens 
    ) external whenForwarderNotPaused returns (bool) {
        
        return _prepareSharesForWithdraw(msg.sender, _amountPoolSharesTokens); 
    }

     function _prepareSharesForWithdraw(
        address _recipient,
        uint256 _amountPoolSharesTokens 
    ) internal returns (bool) {
   
        require( poolSharesToken.balanceOf(_recipient) >= _amountPoolSharesTokens  );

        poolSharesPreparedToWithdrawForLender[_recipient] = _amountPoolSharesTokens; 
        poolSharesPreparedTimestamp[_recipient] = block.timestamp; 


        emit PoolSharesPrepared( 

            _recipient,
            _amountPoolSharesTokens,
           block.timestamp

         );

        return true; 
    }


    /*
       
    */
    function burnSharesToWithdrawEarnings(
        uint256 _amountPoolSharesTokens,
        address _recipient,
        uint256 _minAmountOut
    ) external whenForwarderNotPaused returns (uint256) {
       
        require(poolSharesPreparedToWithdrawForLender[msg.sender] >= _amountPoolSharesTokens,"Shares not prepared for withdraw");
        require(poolSharesPreparedTimestamp[msg.sender] <= block.timestamp - withdrawlDelayTimeSeconds,"Shares not prepared for withdraw");
        
         
        poolSharesPreparedToWithdrawForLender[msg.sender] = 0;
        poolSharesPreparedTimestamp[msg.sender] =  block.timestamp;
  
       
        //this should compute BEFORE shares burn 
        uint256 principalTokenValueToWithdraw = _valueOfUnderlying(
            _amountPoolSharesTokens,
            sharesExchangeRateInverse()
        );

        poolSharesToken.burn(msg.sender, _amountPoolSharesTokens);

        totalPrincipalTokensWithdrawn += principalTokenValueToWithdraw;

        principalToken.safeTransfer(_recipient, principalTokenValueToWithdraw);


        emit EarningsWithdrawn(
            msg.sender,
            _amountPoolSharesTokens,
            principalTokenValueToWithdraw,
            _recipient
        );
        
        require( principalTokenValueToWithdraw >=  _minAmountOut ,"Invalid: Min Amount Out");

        return principalTokenValueToWithdraw;
    }

    /*


    */

    function liquidateDefaultedLoanWithIncentive(
        uint256 _bidId,
        int256 _tokenAmountDifference
    ) public whenForwarderNotPaused bidIsActiveForGroup(_bidId) {
        
        //use original principal amount as amountDue

        uint256 amountDue = _getAmountOwedForBid(_bidId);

        

        uint256 loanDefaultedTimeStamp = ITellerV2(TELLER_V2)
            .getLoanDefaultTimestamp(_bidId);

        int256 minAmountDifference = getMinimumAmountDifferenceToCloseDefaultedLoan(
                amountDue,
                loanDefaultedTimeStamp
            );

        require(
            _tokenAmountDifference >= minAmountDifference,
            "Insufficient tokenAmountDifference"
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
                amountDue + tokensToTakeFromSender - liquidationProtocolFee
            ); 
             
            address protocolOwner = Ownable(address(TELLER_V2)).owner();

              IERC20(principalToken).safeTransferFrom(
                msg.sender,
                address(protocolOwner),
                 liquidationProtocolFee
            );

            totalPrincipalTokensRepaid += amountDue;
            tokenDifferenceFromLiquidations += int256(tokensToTakeFromSender - liquidationProtocolFee );


        } else {
          
           
            uint256 tokensToGiveToSender = abs(minAmountDifference);

           
            IERC20(principalToken).safeTransferFrom(
                msg.sender,
                address(this),
                amountDue - tokensToGiveToSender  
            );

            totalPrincipalTokensRepaid += amountDue;

            //this will make tokenDifference go more negative
            tokenDifferenceFromLiquidations -= int256(tokensToGiveToSender);

           
        }

 

        //this will give collateral to the caller
        ITellerV2(TELLER_V2).lenderCloseLoanWithRecipient(_bidId, msg.sender);
    
    
         emit DefaultedLoanLiquidated(
            _bidId,
            msg.sender,
            amountDue, 
            _tokenAmountDifference
        );
    }

    

    function _getAmountOwedForBid(uint256 _bidId )
        internal
        view
        virtual
        returns (uint256 amountDue)
    {
        (,,,, amountDue, , ,  )
         = ITellerV2(TELLER_V2).getLoanSummary(_bidId);

       
    }


    function getTokenDifferenceFromLiquidations() public view returns (int256){

        return tokenDifferenceFromLiquidations;

    }
    

    /*
        This function will calculate the incentive amount (using a uniswap bonus plus a timer)
        of principal tokens that will be given to incentivize liquidating a loan 
 
    */
    function getMinimumAmountDifferenceToCloseDefaultedLoan(
        uint256 _amountOwed,
        uint256 _loanDefaultedTimestamp
    ) public view virtual returns (int256 amountDifference_) {
        require(
            _loanDefaultedTimestamp > 0,
            "Loan defaulted timestamp must be greater than zero"
        );
        require(
            block.timestamp > _loanDefaultedTimestamp,
            "Loan defaulted timestamp must be in the past"
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


    //this is expanded by 10e18
    //this logic is very similar to that used in LCFA 
    function calculateCollateralTokensAmountEquivalentToPrincipalTokens(
        uint256 principalAmount 
    ) public view virtual returns (uint256 collateralTokensAmountToMatchValue) {
        //same concept as zeroforone
       // (address token0, ) = _getPoolTokens();

        //bool principalTokenIsToken0 = (address(principalToken) == token0);
         //uint256 pairPriceImmediate = _getUniswapV3TokenPairPrice(0);

        uint256 pairPriceWithTwapFromOracle = UniswapPricingLibrary
            .getUniswapPriceRatioForPoolRoutes(poolOracleRoutes);
       
      
       //uint256 scaledPoolOraclePrice = UniswapPricingLibrary.getUniswapPriceRatioForPoolRoutes(
       //         poolOracleRoutes
       //     ).percent(collateralRatio);
 

        uint256 principalPerCollateralAmount = maxPrincipalPerCollateralAmount == 0  
                ? pairPriceWithTwapFromOracle   
                : Math.min(
                    pairPriceWithTwapFromOracle,
                    maxPrincipalPerCollateralAmount //this is expanded by uniswap exp factor  
                ) ;


        return
            getRequiredCollateral(
                principalAmount,
                principalPerCollateralAmount   
            );
    }



   function getRequiredCollateral(
        uint256 _principalAmount,
        uint256 _maxPrincipalPerCollateralAmount 
        
    ) public view virtual returns (uint256) {
         
         return
            MathUpgradeable.mulDiv(
                _principalAmount,
                STANDARD_EXPANSION_FACTOR,
                _maxPrincipalPerCollateralAmount,
                MathUpgradeable.Rounding.Up
            );  
    }
    //this result is expanded by UNISWAP_EXPANSION_FACTOR
   /* function _getUniswapV3TokenPairPrice(uint32 _twapInterval)
        internal
        view
        returns (uint256)
    {
        // represents the square root of the price of token1 in terms of token0

        uint160 sqrtPriceX96 = getSqrtTwapX96(_twapInterval);

        //this output is the price ratio expanded by 1e18
        return _getPriceFromSqrtX96(sqrtPriceX96);
    }

    //this result is expanded by UNISWAP_EXPANSION_FACTOR
    function _getPriceFromSqrtX96(uint160 _sqrtPriceX96)
        internal
        pure
        returns (uint256 price_)
    {
       
         

        uint256 priceX96 = FullMath.mulDiv(uint256(_sqrtPriceX96), uint256(_sqrtPriceX96), (2**96) );

        // sqrtPrice is in X96 format so we scale it down to get the price
        // Also note that this price is a relative price between the two tokens in the pool
        // It's not a USD price
        price_ = priceX96;
    }

    // ---- TWAP

    function getSqrtTwapX96(uint32 twapInterval)
        public
        view
        returns (uint160 sqrtPriceX96)
    {
        if (twapInterval == 0) {
            // return the current price if twapInterval == 0
            (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(UNISWAP_V3_POOL)
                .slot0();
        } else {
            uint32[] memory secondsAgos = new uint32[](2);
            secondsAgos[0] = twapInterval+1; // from (before)
            secondsAgos[1] = 1; // to (now)

            (int56[] memory tickCumulatives, ) = IUniswapV3Pool(UNISWAP_V3_POOL)
                .observe(secondsAgos);

        

              int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
              int24 arithmeticMeanTick = int24(tickCumulativesDelta / int32(twapInterval));
               //// Always round to negative infinity
              if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int32(twapInterval) != 0)) arithmeticMeanTick--;
             
               sqrtPriceX96 = TickMath.getSqrtRatioAtTick(arithmeticMeanTick);


        }
    }
    
    
    function _getPoolTokens()
        internal
        view
        virtual
        returns (address token0, address token1)
    {
        token0 = IUniswapV3Pool(UNISWAP_V3_POOL).token0();
        token1 = IUniswapV3Pool(UNISWAP_V3_POOL).token1();
    }
    
    
    */


    // -----

 
    /*
        Dev Note: pairPriceWithTwap and pairPriceImmediate are expanded by UNISWAP_EXPANSION_FACTOR

    */
   /* function _getCollateralTokensAmountEquivalentToPrincipalTokens(
        uint256 principalTokenAmountValue,
        uint256 pairPrice 
        //uint256 pairPriceImmediate,
       // bool principalTokenIsToken0
    ) public pure returns (uint256 collateralTokensAmountToMatchValue) {
        collateralTokensAmountToMatchValue = token0ToToken1(
                principalTokenAmountValue,
                pairPrice //if this is lower, collateral tokens amt will be higher
            );
    }

    //note: the price is still expanded by UNISWAP_EXPANSION_FACTOR
    function token0ToToken1(uint256 amountToken0, uint256 priceToken1PerToken0)
        internal
        pure
        returns (uint256)
    {
        return
            MathUpgradeable.mulDiv(
                amountToken0,
                UNISWAP_EXPANSION_FACTOR,
                priceToken1PerToken0,
                MathUpgradeable.Rounding.Up
            );
    }

    //note: the price is still expanded by UNISWAP_EXPANSION_FACTOR
    function token1ToToken0(uint256 amountToken1, uint256 priceToken1PerToken0)
        internal
        pure
        returns (uint256)
    {
        return
            MathUpgradeable.mulDiv(
                amountToken1,
                priceToken1PerToken0,
                UNISWAP_EXPANSION_FACTOR,
                MathUpgradeable.Rounding.Up
            );
    }*/

    /*
    This  callback occurs when a TellerV2 repayment happens or when a TellerV2 liquidate happens 

    lenderCloseLoan does not trigger a repayLoanCallback 
    */
    function repayLoanCallback(
        uint256 _bidId,
        address repayer,
        uint256 principalAmount,
        uint256 interestAmount
    ) external onlyTellerV2 whenForwarderNotPaused {
        //can use principal amt to increment amt paid back!! nice for math .
        totalPrincipalTokensRepaid += principalAmount;
        totalInterestCollected += interestAmount;

         emit LoanRepaid(
            _bidId,
            repayer,
            principalAmount,
            interestAmount,
            totalPrincipalTokensRepaid,
            totalInterestCollected
        );
    }


    /*
        If principaltokens get stuck in the escrow vault for any reason, anyone may
        call this function to move them from that vault in to this contract 
    */
    function withdrawFromEscrowVault ( uint256 _amount ) public whenForwarderNotPaused  {


        address _escrowVault = ITellerV2(TELLER_V2).getEscrowVault();

        IEscrowVault(_escrowVault).withdraw(address(principalToken), _amount );

    }
 
  
    function getTotalPrincipalTokensOutstandingInActiveLoans()
        public
        view
        returns (uint256)
    {
        return totalPrincipalTokensLended - totalPrincipalTokensRepaid;
    }




    function getCollateralTokenAddress() external view returns (address) {
        return address(collateralToken);
    }

    function getCollateralTokenId() external view returns (uint256) {
        return 0;
    }

    function getCollateralTokenType()
        external
        view
        returns (CommitmentCollateralType)
    {
        return CommitmentCollateralType.ERC20;
    }

    //this was a redundant function 
   /* function getRequiredCollateral(uint256 _principalAmount)
        public
        view
        returns (uint256 requiredCollateral_)
    {
        requiredCollateral_ = getCollateralRequiredForPrincipalAmount(
            _principalAmount
        );
    }*/

    function getMarketId() external view returns (uint256) {
        return marketId;
    }

    function getMaxLoanDuration() external view returns (uint32) {
        return maxLoanDuration;
    }


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

  function getMinInterestRate(uint256 amountDelta) public view returns (uint16) {
        return interestRateLowerBound + 
        uint16( uint256(interestRateUpperBound-interestRateLowerBound)
        .percent(getPoolUtilizationRatio(amountDelta )
        
        ) );
    } 
    

    function getPrincipalTokenAddress() external view returns (address) {
        return address(principalToken);
    }

   

    function getPrincipalAmountAvailableToBorrow()
        public
        view
        returns (uint256)
    {     

            return  ( uint256( getPoolTotalEstimatedValue() )).percent(liquidityThresholdPercent) -
            getTotalPrincipalTokensOutstandingInActiveLoans() ;
     
    }

    /**
     * @notice Lets the DAO/owner of the protocol implement an emergency stop mechanism.
     */
    function pauseBorrowing() public virtual onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @notice Lets the DAO/owner of the protocol undo a previously implemented emergency stop.
     */
    function unpauseBorrowing() public virtual onlyOwner whenPaused {
        _unpause();
    }
}
