// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Contracts
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interfaces
import "../../../interfaces/ITellerV2Context.sol";
import "../../../interfaces/IProtocolFee.sol";
import "../../../interfaces/ITellerV2Storage.sol";
import "../../../interfaces/ITellerV2.sol";

import "../../../interfaces/IFlashRolloverLoan.sol";
import "../../../libraries/NumbersLib.sol";

import "../../../interfaces/uniswap/IUniswapV3Pool.sol";

import "../../../interfaces/uniswap/IUniswapV3Factory.sol";

import "../../../libraries/uniswap/TickMath.sol";
import "../../../libraries/uniswap/FixedPoint96.sol";
import "../../../libraries/uniswap/FullMath.sol";

import "./LenderCommitmentGroupShares.sol";

import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import { CommitmentCollateralType, ISmartCommitment } from "../../../interfaces/ISmartCommitment.sol";
import { ILoanRepaymentListener } from "../../../interfaces/ILoanRepaymentListener.sol";

import { ILoanRepaymentCallbacks } from "../../../interfaces/ILoanRepaymentCallbacks.sol";

import { ILenderCommitmentGroup } from "../../../interfaces/ILenderCommitmentGroup.sol";
import { Payment } from "../../../TellerV2Storage.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/*



////----


1. Use 50% forced max utilization ratio as initial game theory - have a global utilization limit and a user-signalled utilization limit (based on shares signalling) 

2. When pool shares are burned, give the lender : [ their pct shares *  ( currentPrincipalTokens in contract, totalCollateralShares, totalInterestCollected)   ] and later, they can burn the collateral shares for any collateral tokens that are in the contract. 
3. use noahs TToken contract as reference for ratios -> amt of tokens to get when committing 
4.  Need price oracle bc we dont want to use maxPrincipalPerCollateral ratio as a static ideally 
5. have an LTV ratio 

Every time a lender deposits tokens, we can mint an equal amt of RepresentationToken


// -- LIMITATIONS 
1. neither the principal nor collateral token shall not have more than 18 decimals due to the way expansion is configured


// -- EXITING 

When exiting, a lender is burning X shares 

 -  We calculate the total equity value (Z) of the pool  multiplies by their pct of shares (S%)    (naive is just total committed princ tokens and interest , could maybe do better  )
    - We are going to give the lender  (Z * S%) value.  The way we are going to give it to them is in a split of principal (P) and collateral tokens (C)  which are in the pool right now.   Similar to exiting a uni pool .   C tokens will only be in the pool if bad defaults happened.  
    
         NOTE:  We will know the price of C in terms of P due to the ratio of total P used for loans and total C used for loans 
         
         NOTE: if there are not enough P and C tokens in the pool to give the lender to equal a value of (Z * S%) then we revert . 

// ---------


// ISSUES 

1. for 'overall pool value' calculations (for shares math) an active loans value should be treated as "principal+interest"
   aka the amount that will be paid to the pool optimistically.  DONE 
2. Redemption with ' the split' of principal and collateral is not ideal .  What would be more ideal is a "conversion auction' or a 'swap auction'. 
    In this paradigm, any party can offer to give X principal tokens for the Y collateral tokens that are in the pool.  the auction lasts (1 hour?)  and this way it is always only principal tha is being withdrawn - far less risk of MEV attacker taking more C -- DONE 
3. it is annoying that a bad default can cause a pool to have to totally exit and close ..this is a minor issue. maybe some form of Insurance can help resurrect a pool in this case, mayeb anyone can restore the health of the pool w a fn call.  
    a. fix this by changing the shares logic so you do get more shares in this event (i dont think its possible) 
    b. have a function that lets anyone donate principal tokens to make the pool whole again .  (refill underwater pools w insurance fund??)
    c. lets pools expire and get unwound and withdrawn completely , make a new pool 

4. build a function to do lender close loan 



TODO: 
A. Make a mental map of these subsystems, attack vectors, mitigaions 

B. 


// ----- 



// TODO 


 
 2. consider adding PATHS to this for the oracle.. so the pair can be USDC to PNDC but use weth as intermediate 
 4. tests 

// ----



 

If a lender puts up 50,000 originally, im able to withdraw all my deposits.  Everyone else is in the hole until a borrower repays a loan 
If there isnt enough liquidity, you just cannot burn those shares. 

 
  
 
Consider implementing eip-4626


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

    uint256 public immutable UNISWAP_EXPANSION_FACTOR = 2**96;

    uint256 public immutable EXCHANGE_RATE_EXPANSION_FACTOR = 1e36; //consider making this dynamic

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable TELLER_V2;
    address public immutable SMART_COMMITMENT_FORWARDER;
    address public immutable UNISWAP_V3_FACTORY;
    address public UNISWAP_V3_POOL;

    // bool private _initialized;

    LenderCommitmentGroupShares public poolSharesToken;

    IERC20 public principalToken;
    IERC20 public collateralToken;

    uint256 marketId;

    //this should be the net total principal tokens ,  lenderAdded - lenderWithdrawn
    uint256 public totalPrincipalTokensCommitted;

    uint256 public totalPrincipalTokensLended;
    uint256 public totalPrincipalTokensRepaid; //subtract this and the above to find total principal tokens outstanding for loans

    uint256 public totalCollateralTokensEscrowedForLoans; // we use this in conjunction with totalPrincipalTokensLended for a psuedo TWAP price oracle of C tokens, used for exiting  .  Nice bc it is averaged over all of our relevant loans, not the current price.

    uint256 public totalInterestCollected;

    uint16 public liquidityThresholdPercent; //5000 is 50 pct  // enforce max of 10000
    uint16 public loanToValuePercent; //the overcollateralization ratio, typically 80 pct

    uint32 public twapInterval;
    uint32 public maxLoanDuration;
    uint16 public interestRateLowerBound;
    uint16 public interestRateUpperBound;


    mapping(address => uint256) public principalTokensCommittedByLender;
    mapping(uint256 => bool) public activeBids;

    //this excludes interest
    // maybe it is possible to get rid of this storage slot and calculate it from totalPrincipalTokensRepaid, totalPrincipalTokensLended
    int256 tokenDifferenceFromLiquidations;


   

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

    modifier bidIsActiveForGroup(uint256 _bidId) {
        require(activeBids[_bidId] == true, "Bid is not active for group");

        _;
    }



    event PoolInitialized(
        address indexed principalTokenAddress,
        address indexed collateralTokenAddress,
        uint256 marketId,
        uint32 maxLoanDuration,
        uint16 interestRateLowerBound,
        uint16 interestRateUpperBound,
        uint16 liquidityThresholdPercent,
        uint16 loanToValuePercent,
        uint24 uniswapPoolFee,
        uint32 twapInterval,
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
        address _principalTokenAddress,
        address _collateralTokenAddress,
        uint256 _marketId,
        uint32 _maxLoanDuration,
        uint16 _interestRateLowerBound,
        uint16 _interestRateUpperBound,
        uint16 _liquidityThresholdPercent, // When 100% , the entire pool can be drawn for lending.  When 80%, only 80% of the pool can be drawn for lending. 
        uint16 _loanToValuePercent, //the required overcollateralization ratio.  10000 is 1:1 baseline , typically this is above 10000
        uint24 _uniswapPoolFee,
        uint32 _twapInterval
    ) external initializer returns (address poolSharesToken_) {
        // require(!_initialized,"already initialized");
        // _initialized = true;

        __Pausable_init();

        principalToken = IERC20(_principalTokenAddress);
        collateralToken = IERC20(_collateralTokenAddress);

        UNISWAP_V3_POOL = IUniswapV3Factory(UNISWAP_V3_FACTORY).getPool(
            _principalTokenAddress,
            _collateralTokenAddress,
            _uniswapPoolFee
        );

        require(UNISWAP_V3_POOL != address(0), "Invalid uniswap pool address");

        marketId = _marketId;

        //in order for this to succeed, first, that SmartCommitmentForwarder needs to be THE trusted forwarder for the market

        //approve this market as a forwarder
        ITellerV2Context(TELLER_V2).approveMarketForwarder(
            _marketId,
            SMART_COMMITMENT_FORWARDER
        );

        maxLoanDuration = _maxLoanDuration;
        interestRateLowerBound = _interestRateLowerBound;
        interestRateUpperBound = _interestRateUpperBound;


        
        require(interestRateUpperBound <= 10000, "invalid _interestRateUpperBound");
        require(interestRateLowerBound <= interestRateUpperBound, "invalid _interestRateLowerBound");

        require(_liquidityThresholdPercent <= 10000, "invalid _liquidityThresholdPercent"); 

        liquidityThresholdPercent = _liquidityThresholdPercent;
        loanToValuePercent = _loanToValuePercent;
        twapInterval = _twapInterval;

        
        poolSharesToken_ = _deployPoolSharesToken();


        emit PoolInitialized(
            _principalTokenAddress,
            _collateralTokenAddress,
            _marketId,
            _maxLoanDuration,
            _interestRateLowerBound,
            _interestRateUpperBound,
            _liquidityThresholdPercent,
            _loanToValuePercent,
            _uniswapPoolFee,
            _twapInterval,
            poolSharesToken_
        );
    }

    function _deployPoolSharesToken()
        internal
        onlyInitializing
        returns (address poolSharesToken_)
    {
        // uint256 principalTokenDecimals = principalToken.decimals();

        require(
            address(poolSharesToken) == address(0),
            "Pool shares already deployed"
        );

        poolSharesToken = new LenderCommitmentGroupShares(
            "PoolShares",
            "PSH",
            18 //may want this to equal the decimals of principal token !?
        );

        return address(poolSharesToken);
    }

    /**
     * @notice This determines the number of shares you get for depositing principal tokens and the number of principal tokens you receive for burning shares
     * @return rate_ The current exchange rate, scaled by the EXCHANGE_RATE_FACTOR.
     */

    function sharesExchangeRate() public view virtual returns (uint256 rate_) {
        /*
        Should get slightly less shares than principal tokens put in !! diluted by ratio of pools actual equity 
       */

        uint256 poolTotalEstimatedValue = getPoolTotalEstimatedValue();
        uint256 poolTotalEstimatedValuePlusInterest = poolTotalEstimatedValue +
            totalInterestCollected;

        if (poolTotalEstimatedValue == 0) {
            return EXCHANGE_RATE_EXPANSION_FACTOR; // 1 to 1 for first swap
        }

        rate_ =
            (poolTotalEstimatedValuePlusInterest *
                EXCHANGE_RATE_EXPANSION_FACTOR) /
            poolTotalEstimatedValue;
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
        int256 poolTotalEstimatedValueSigned = int256(
            totalPrincipalTokensCommitted
        ) + tokenDifferenceFromLiquidations;

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
        address _sharesRecipient
    ) external returns (uint256 sharesAmount_) {
        //transfers the primary principal token from msg.sender into this contract escrow
        //gives
        principalToken.transferFrom(msg.sender, address(this), _amount);

        sharesAmount_ = _valueOfUnderlying(_amount, sharesExchangeRate());

        totalPrincipalTokensCommitted += _amount;
        principalTokensCommittedByLender[msg.sender] += _amount;

        //mint shares equal to _amount and give them to the shares recipient !!!
        poolSharesToken.mint(_sharesRecipient, sharesAmount_);

        emit LenderAddedPrincipal( 

            msg.sender,
            _amount,
            sharesAmount_,
            _sharesRecipient

         );
    }

    function _valueOfUnderlying(uint256 amount, uint256 rate)
        internal
        pure
        returns (uint256 value_)
    {
        if (rate == 0) {
            return 0;
        }

        value_ = (amount * EXCHANGE_RATE_EXPANSION_FACTOR) / rate;
    }

    function acceptFundsForAcceptBid(
        address _borrower,
        uint256 _bidId,
        uint256 _principalAmount,
        uint256 _collateralAmount,
        address _collateralTokenAddress,
        uint256 _collateralTokenId, //not used
        uint32 _loanDuration,
        uint16 _interestRate
    ) external onlySmartCommitmentForwarder whenNotPaused {
        //consider putting these into less readonly fn calls
        require(
            _collateralTokenAddress == address(collateralToken),
            "Mismatching collateral token"
        );
        //the interest rate must be at least as high has the commitment demands. The borrower can use a higher interest rate although that would not be beneficial to the borrower.
        require(_interestRate >= getMinInterestRate(), "Invalid interest rate");
        //the loan duration must be less than the commitment max loan duration. The lender who made the commitment expects the money to be returned before this window.
        require(_loanDuration <= maxLoanDuration, "Invalid loan max duration");

        require(
            getPrincipalAmountAvailableToBorrow() >= _principalAmount,
            "Invalid loan max principal"
        );

        require(isAllowedToBorrow(_borrower), "unauthorized borrow");

        //this is expanded by 10**18
        uint256 requiredCollateral = getCollateralRequiredForPrincipalAmount(
            _principalAmount
        );

        require(
            (_collateralAmount * STANDARD_EXPANSION_FACTOR) >=
                requiredCollateral,
            "Insufficient Borrower Collateral"
        );

        //consider changing how this works
        principalToken.approve(address(TELLER_V2), _principalAmount);

        //do not have to spoof/forward as this contract is the lender !
        _acceptBidWithRepaymentListener(_bidId);

        totalPrincipalTokensLended += _principalAmount;

        activeBids[_bidId] = true; //bool for now
      
      
        //emit event
        //we know the principal token and collateral token addresses since they are hard set in this contract 
 
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

    /*
       
    */
    function burnSharesToWithdrawEarnings(
        uint256 _amountPoolSharesTokens,
        address _recipient
    ) external returns (uint256) {
       

        //this reduces total supply
        poolSharesToken.burn(msg.sender, _amountPoolSharesTokens);

        uint256 principalTokenValueToWithdraw = _valueOfUnderlying(
            _amountPoolSharesTokens,
            sharesExchangeRateInverse()
        );

        totalPrincipalTokensCommitted -= principalTokenValueToWithdraw;

        principalToken.transfer(_recipient, principalTokenValueToWithdraw);

        emit EarningsWithdrawn(
            msg.sender,
            _amountPoolSharesTokens,
            principalTokenValueToWithdraw,
            _recipient
        );

        return principalTokenValueToWithdraw;
    }

    /*


    */

    function liquidateDefaultedLoanWithIncentive(
        uint256 _bidId,
        int256 _tokenAmountDifference
    ) public bidIsActiveForGroup(_bidId) {
        uint256 amountDue = getAmountOwedForBid(_bidId, false);

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


     

        if (_tokenAmountDifference > 0) {
            //this is used when the collateral value is higher than the principal (rare)
            //the loan will be completely made whole and our contract gets extra funds too
            uint256 tokensToTakeFromSender = abs(_tokenAmountDifference);

            IERC20(principalToken).transferFrom(
                msg.sender,
                address(this),
                amountDue + tokensToTakeFromSender
            );

            tokenDifferenceFromLiquidations += int256(tokensToTakeFromSender);

            totalPrincipalTokensRepaid += amountDue;
        } else {
            //the loan will be not be made whole and will be short

            uint256 tokensToGiveToSender = abs(_tokenAmountDifference);

            IERC20(principalToken).transferFrom(
                msg.sender,
                address(this),
                amountDue - tokensToGiveToSender
            );

            tokenDifferenceFromLiquidations -= int256(tokensToGiveToSender);

            totalPrincipalTokensRepaid += (amountDue - tokensToGiveToSender);
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

    function getAmountOwedForBid(uint256 _bidId, bool _includeInterest)
        public
        view
        virtual
        returns (uint256 amountOwed_)
    {
        Payment memory amountOwedPayment = ITellerV2(TELLER_V2)
            .calculateAmountOwed(_bidId, block.timestamp);

        amountOwed_ = _includeInterest
            ? amountOwedPayment.principal + amountOwedPayment.interest
            : amountOwedPayment.principal;
    }

    /*
        This function will calculate the incentive amount (using a uniswap bonus plus a timer)
        of principal tokens that will be given to incentivize liquidating a loan 

        Starts at 5000 and ticks down to -5000 
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

        //make this 10000 be a param in the constructor
        int256 incentiveMultiplier = int256(10000) -
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

    //this is expanded by 1e18
    function getCollateralRequiredForPrincipalAmount(uint256 _principalAmount)
        public
        view
        returns (uint256)
    {
        uint256 baseAmount = _calculateCollateralTokensAmountEquivalentToPrincipalTokens(
                _principalAmount
            );

        //this is an amount of collateral
        return baseAmount.percent(loanToValuePercent);
    }

    //remember that this result is expanded by UNISWAP_EXPANSION_FACTOR
    function _getUniswapV3TokenPairPrice(uint32 _twapInterval)
        internal
        view
        returns (uint256)
    {
        // represents the square root of the price of token1 in terms of token0

        uint160 sqrtPriceX96 = getSqrtTwapX96(_twapInterval);

        //this output is the price ratio expanded by 1e18
        return _getPriceFromSqrtX96(sqrtPriceX96);
    }

    //remember that this result is expanded by UNISWAP_EXPANSION_FACTOR
    function _getPriceFromSqrtX96(uint160 _sqrtPriceX96)
        internal
        pure
        returns (uint256 price_)
    {
        // uint160 sqrtPrice =  _sqrtPriceX96    ;

        uint256 priceX96 = (uint256(_sqrtPriceX96) * uint256(_sqrtPriceX96)) /
            (2**96);

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
            secondsAgos[0] = twapInterval; // from (before)
            secondsAgos[1] = 0; // to (now)

            (int56[] memory tickCumulatives, ) = IUniswapV3Pool(UNISWAP_V3_POOL)
                .observe(secondsAgos);

            // tick(imprecise as it's an integer) to price
            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
                int24(
                    (tickCumulatives[1] - tickCumulatives[0]) /
                        int32(twapInterval)
                )
            );
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

    // -----

    //this is expanded by 10e18
    function _calculateCollateralTokensAmountEquivalentToPrincipalTokens(
        uint256 principalTokenAmountValue
    ) internal view returns (uint256 collateralTokensAmountToMatchValue) {
        //same concept as zeroforone
        (address token0, ) = _getPoolTokens();

        bool principalTokenIsToken0 = (address(principalToken) == token0);

        uint256 pairPriceWithTwap = _getUniswapV3TokenPairPrice(twapInterval);
        uint256 pairPriceImmediate = _getUniswapV3TokenPairPrice(0);

        return
            _getCollateralTokensAmountEquivalentToPrincipalTokens(
                principalTokenAmountValue,
                pairPriceWithTwap,
                pairPriceImmediate,
                principalTokenIsToken0
            );
    }

    /*
        Dev Note: pairPriceWithTwap and pairPriceImmediate are expanded by UNISWAP_EXPANSION_FACTOR

    */
    function _getCollateralTokensAmountEquivalentToPrincipalTokens(
        uint256 principalTokenAmountValue,
        uint256 pairPriceWithTwap,
        uint256 pairPriceImmediate,
        bool principalTokenIsToken0
    ) internal pure returns (uint256 collateralTokensAmountToMatchValue) {
        if (principalTokenIsToken0) {
            //token 1 to token 0 ?
            uint256 worstCasePairPrice = Math.min(
                pairPriceWithTwap,
                pairPriceImmediate
            );

            collateralTokensAmountToMatchValue = token1ToToken0(
                principalTokenAmountValue,
                worstCasePairPrice //if this is lower, collateral tokens amt will be higher
            );
        } else {
            //token 0 to token 1 ?
            uint256 worstCasePairPrice = Math.max(
                pairPriceWithTwap,
                pairPriceImmediate
            );

            collateralTokensAmountToMatchValue = token0ToToken1(
                principalTokenAmountValue,
                worstCasePairPrice //if this is lower, collateral tokens amt will be higher
            );
        }
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
    }

    /*
    This  callback occurs when a TellerV2 repayment happens or when a TellerV2 liquidate happens 

    lenderCloseLoan does not trigger a repayLoanCallback 
    */
    function repayLoanCallback(
        uint256 _bidId,
        address repayer,
        uint256 principalAmount,
        uint256 interestAmount
    ) external onlyTellerV2 {
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

    function getAverageWeightedPriceForCollateralTokensPerPrincipalTokens()
        public
        view
        returns (uint256)
    {
        if (totalPrincipalTokensLended <= 0) {
            return 0;
        }

        return
            totalCollateralTokensEscrowedForLoans / totalPrincipalTokensLended;
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

    //this is expanded by 1e18
    //this only exists to comply with the interface
    function getRequiredCollateral(uint256 _principalAmount)
        public
        view
        returns (uint256 requiredCollateral_)
    {
        requiredCollateral_ = getCollateralRequiredForPrincipalAmount(
            _principalAmount
        );
    }

    function getMarketId() external view returns (uint256) {
        return marketId;
    }

    function getMaxLoanDuration() external view returns (uint32) {
        return maxLoanDuration;
    }

    //this is always between 0 and 10000
    function getPoolUtilizationRatio() public view returns (uint16) {

        if (totalPrincipalTokensCommitted == 0) {
            return 0;
        }

        return uint16(  Math.min(  (totalPrincipalTokensLended - totalPrincipalTokensRepaid)  * 10000  /   totalPrincipalTokensCommitted , 10000  ));
    }   

 
    function getMinInterestRate() public view returns (uint16) {
        return interestRateLowerBound + uint16( uint256(interestRateUpperBound-interestRateLowerBound).percent(getPoolUtilizationRatio()) );
    }

    function getPrincipalTokenAddress() external view returns (address) {
        return address(principalToken);
    }

    function isAllowedToBorrow(address borrower) public view returns (bool) {
        return true;
    }

    function getPrincipalAmountAvailableToBorrow()
        public
        view
        returns (uint256)
    {
        int256 amountAvailable = int256(totalPrincipalTokensCommitted) -
            int256(getTotalPrincipalTokensOutstandingInActiveLoans()) +
            tokenDifferenceFromLiquidations;

        return uint256(amountAvailable).percent(liquidityThresholdPercent);
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
