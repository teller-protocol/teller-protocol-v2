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

import "./LenderCommitmentGroupShares.sol";

import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import { CommitmentCollateralType, ISmartCommitment } from "../../../interfaces/ISmartCommitment.sol";
import { ILoanRepaymentListener } from "../../../interfaces/ILoanRepaymentListener.sol";

import { ILenderCommitmentGroup } from "../../../interfaces/ILenderCommitmentGroup.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "lib/forge-std/src/console.sol";

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
    ILenderCommitmentGroup,
    ISmartCommitment,
    ILoanRepaymentListener,
    Initializable
{
    using AddressUpgradeable for address;
    using NumbersLib for uint256;

    uint256 public immutable EXCHANGE_RATE_EXPANSION_FACTOR = 1e18;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    //ITellerV2 public immutable TELLER_V2;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable TELLER_V2;
    address public immutable SMART_COMMITMENT_FORWARDER;
    address public immutable UNISWAP_V3_FACTORY;
    address public UNISWAP_V3_POOL;

    bool private _initialized;

    LenderCommitmentGroupShares public poolSharesToken;

    IERC20 public principalToken;
    IERC20 public collateralToken;

    uint256 marketId; //remove the marketId enforcement ???
    uint32 maxLoanDuration;
    uint16 minInterestRate;

    //this is all of the principal tokens that have been committed to this contract minus all that have been withdrawn.  This includes the tokens in this contract and lended out in active loans by this contract.

    //run lots of tests in which tokens are donated to this contract to be uncommitted to make sure things done break
    // tokens donated to this contract should be ignored?

    uint256 public totalPrincipalTokensCommitted; //this can be less than we expect if tokens are donated to the contract and withdrawn

    uint256 public totalPrincipalTokensLended;
    uint256 public totalPrincipalTokensRepaid; //subtract this and the above to find total principal tokens outstanding for loans

    uint256 public totalCollateralTokensEscrowedForLoans; // we use this in conjunction with totalPrincipalTokensLended for a psuedo TWAP price oracle of C tokens, used for exiting  .  Nice bc it is averaged over all of our relevant loans, not the current price.

    uint256 public totalInterestCollected;
    uint256 public totalInterestWithdrawn;

    uint16 public liquidityThresholdPercent; //5000 is 50 pct  // enforce max of 10000
    uint16 public loanToValuePercent; //the overcollateralization ratio, typically 80 pct

    mapping(address => uint256) public principalTokensCommittedByLender;

    //try to make apy dynamic .

    modifier onlyAfterInitialized() {
        require(_initialized, "Contract must be initialized");
        _;
    }

    modifier onlySmartCommitmentForwarder() {
        require(
            msg.sender == address(SMART_COMMITMENT_FORWARDER),
            "Can only be called by Smart Commitment Forwarder"
        );
        _;
    }

    //maybe make this an initializer instead !?
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

    // must send initial principal tokens into this contract just before this is called
    function initialize(
        address _principalTokenAddress,
        address _collateralTokenAddress,
       
        uint256 _marketId,
        uint32 _maxLoanDuration,
        uint16 _minInterestRate,
        uint16 _liquidityThresholdPercent,
        uint16 _loanToValuePercent, //essentially the overcollateralization ratio.  10000 is 1:1 baseline ? // initializer  ADD ME
        uint24 _uniswapPoolFee
        
    )   
        initializer
        external
        returns (
            
            address poolSharesToken_
        )
    {
        require(!_initialized,"already initialized");
        _initialized = true; //not necessary ? 

        principalToken = IERC20(_principalTokenAddress);
        collateralToken = IERC20(_collateralTokenAddress);

        
        UNISWAP_V3_POOL = IUniswapV3Factory(UNISWAP_V3_FACTORY).getPool( 
            _principalTokenAddress,
            _collateralTokenAddress,
            _uniswapPoolFee
         );

         require(UNISWAP_V3_POOL != address(0), "Invalid uniswap pool address");


       
        marketId = _marketId;

        //approve this market as a forwarder 
        ITellerV2Context(TELLER_V2).approveMarketForwarder( _marketId, SMART_COMMITMENT_FORWARDER );


        maxLoanDuration = _maxLoanDuration;
        minInterestRate = _minInterestRate;

        require(_liquidityThresholdPercent <= 10000, "invalid threshold");

        liquidityThresholdPercent = _liquidityThresholdPercent;
        loanToValuePercent = _loanToValuePercent;

        // maxPrincipalPerCollateralAmount = _maxPrincipalPerCollateralAmount;
        // _createInitialCommitment(_createCommitmentArgs);

        // set initial terms in storage from _createCommitmentArgs

        poolSharesToken_ = _deployPoolSharesToken();

    }

    function _deployPoolSharesToken()
        internal
        returns (address poolSharesToken_)
    {
        // uint256 principalTokenDecimals = principalToken.decimals();

        poolSharesToken = new LenderCommitmentGroupShares(
            "PoolShares",
            "PSH",
            18 //may want this to equal the decimals of principal token !?
        );

        return address(poolSharesToken);
    }

    /**
     * @notice It calculates the current scaled exchange rate for a whole Teller Token based of the underlying token balance.
     * @return rate_ The current exchange rate, scaled by the EXCHANGE_RATE_FACTOR.
     */
    function sharesExchangeRate() public view returns (uint256 rate_) {
        /*
        Should get slightly less shares than principal tokens put in !! diluted by ratio of pools actual equity 
       */

        uint256 poolTotalEstimatedValue = totalPrincipalTokensCommitted;
        uint256 poolTotalEstimatedValuePlusInterest = totalPrincipalTokensCommitted +
                totalInterestCollected;

        if (poolTotalEstimatedValue == 0) {
            return EXCHANGE_RATE_EXPANSION_FACTOR; // 1 to 1 for first swap
        }

        rate_ =
            (poolTotalEstimatedValuePlusInterest *
                EXCHANGE_RATE_EXPANSION_FACTOR) /
            poolTotalEstimatedValue;
    }

    /*
When exiting, a lender is burning X shares 

We calculate the total equity value (Z) of the pool  
multiplies by their pct of shares (S%)    
(naive is just total committed princ tokens and interest ,
 could maybe do better  )
  We are going to give the lender  (Z * S%) value. 
   The way we are going to give it to them is in a split of
    principal (P) and collateral tokens (C)  which are in
    the pool right now.   Similar to exiting a uni pool .  
     C tokens will only be in the pool if bad defaults happened.  
    
  NOTE:  We will know the price of C in terms of P due to
   the ratio of total P used for loans and total C used for loans 
         
 NOTE: if there are not enough P and C tokens in the pool to 
 give the lender to equal a value of (Z * S%) then we revert . 
 
*/

    function collateralTokenExchangeRate() public view returns (uint256 rate_) {
        uint256 totalPrincipalTokensUsedForLoans = totalPrincipalTokensLended -
            totalPrincipalTokensRepaid;
        uint256 totalCollateralTokensUsedForLoans = totalCollateralTokensEscrowedForLoans;

        if (totalPrincipalTokensUsedForLoans == 0) {
            return EXCHANGE_RATE_EXPANSION_FACTOR; // 1 to 1 for first swap
        }

        rate_ =
            (totalCollateralTokensUsedForLoans *
                EXCHANGE_RATE_EXPANSION_FACTOR) /
            totalPrincipalTokensUsedForLoans;
    }

    /* function currentTVL() public override returns (uint256 tvl_) {
        tvl_ += totalUnderlyingSupply();
        tvl_ += s().totalBorrowed;
        tvl_ -= s().totalRepaid;
    }
  
*/
    /*
    must be initialized for this to work ! 
    */
    function addPrincipalToCommitmentGroup(
        uint256 _amount,
        address _sharesRecipient
    ) external onlyAfterInitialized returns (uint256 sharesAmount_) {
        //transfers the primary principal token from msg.sender into this contract escrow
        //gives
        principalToken.transferFrom(msg.sender, address(this), _amount);

        totalPrincipalTokensCommitted += _amount;
        principalTokensCommittedByLender[msg.sender] += _amount;

        
        sharesAmount_ = _valueOfUnderlying(_amount, sharesExchangeRate());

        //mint shares equal to _amount and give them to the shares recipient !!!
        poolSharesToken.mint(_sharesRecipient, sharesAmount_);
    }

    function _valueOfUnderlying(uint256 amount, uint256 rate)
        internal
        pure
        returns (uint256 value_)
    {
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
    ) external onlySmartCommitmentForwarder {
        //consider putting these into less readonly fn calls
        require(
            _collateralTokenAddress == address(collateralToken),
            "Mismatching collateral token"
        );
        //the interest rate must be at least as high has the commitment demands. The borrower can use a higher interest rate although that would not be beneficial to the borrower.
        require(_interestRate >= minInterestRate, "Invalid interest rate");
        //the loan duration must be less than the commitment max loan duration. The lender who made the commitment expects the money to be returned before this window.
        require(_loanDuration <= maxLoanDuration, "Invalid loan max duration");
    
        require(
            getPrincipalAmountAvailableToBorrow() >= _principalAmount,
            "Invalid loan max principal"
        );

        require(isAllowedToBorrow(_borrower), "unauthorized borrow");

        

        uint256 requiredCollateral = getRequiredCollateral(_principalAmount);

        require(
            _collateralAmount >= requiredCollateral,
            "Insufficient Borrower Collateral"
        );

            //consider changing how this works 
        principalToken.approve(address(TELLER_V2), _principalAmount);

        //do not have to spoof/forward as this contract is the lender ! 
        _acceptBidWithRepaymentListener(
            _bidId 
        );

        totalPrincipalTokensLended += _principalAmount;

        //emit event
    }

    function  _acceptBidWithRepaymentListener(
        uint256 _bidId 
    ) internal {

        ITellerV2(TELLER_V2).lenderAcceptBid(_bidId); //this gives out the funds to the borrower
        
        ITellerV2(TELLER_V2).setRepaymentListenerForBid(_bidId, address(this));

    }

    /*
    must be initialized for this to work ! 
    */
    function burnSharesToWithdrawEarnings(
        uint256 _amountPoolSharesTokens,
        address _recipient
    )
        external
        onlyAfterInitialized
        returns (
            uint256 principalTokenSplitAmount_,
            uint256 collateralTokenSplitAmount_
        )
    {
        //uint256 collectedInterest = LoanRepaymentInterestCollector( interestCollector ).collectInterest();

        //figure out the ratio of shares tokens that this is
        uint256 poolSharesTotalSupplyBeforeBurn = poolSharesToken.totalSupply();

        //this DOES reduce total supply! This is necessary for correct math.
        poolSharesToken.burn(msg.sender, _amountPoolSharesTokens);

        uint256 netCommittedTokens = totalPrincipalTokensCommitted;

        uint256 principalTokenEquityAmountSimple = totalPrincipalTokensCommitted +
                totalInterestCollected -
                (totalInterestWithdrawn);

       

        uint256 principalTokenValueToWithdraw = (principalTokenEquityAmountSimple *
                _amountPoolSharesTokens) / poolSharesTotalSupplyBeforeBurn;
        uint256 tokensToUncommit = (netCommittedTokens *
            _amountPoolSharesTokens) / poolSharesTotalSupplyBeforeBurn;

      

        totalPrincipalTokensCommitted -= tokensToUncommit;
        // totalPrincipalTokensUncommitted += tokensToUncommit;

        totalInterestWithdrawn +=
            principalTokenValueToWithdraw -
            tokensToUncommit;
 
        principalTokensCommittedByLender[
            msg.sender
        ] -= principalTokenValueToWithdraw;

        //implement this --- needs to be based on the amt of tokens in the contract right now !!
        (
            principalTokenSplitAmount_,
            collateralTokenSplitAmount_
        ) = calculateSplitTokenAmounts(principalTokenValueToWithdraw);

       
        principalToken.transfer(_recipient, principalTokenSplitAmount_);
        collateralToken.transfer(_recipient, collateralTokenSplitAmount_);

        console.log("sent split amt ");

        //also mint collateral token shares !!  or give them out .
    }

    /*
        careful with this because someone donating tokens into the contract could make for weird math ?
    */
    function calculateSplitTokenAmounts(uint256 _principalTokenAmountValue)
        public
        view
        returns (uint256 principalAmount_, uint256 collateralAmount_)
    { 

        // need to see how many collateral tokens are in the contract atm

        // need to know how many principal tokens are in the contract atm
        uint256 principalTokenBalance = principalToken.balanceOf(address(this)); //this is also the principal token value
        uint256 collateralTokenBalance = collateralToken.balanceOf(
            address(this)
        );

        //  need to know how the value of the collateral tokens  IN TERMS OF principal tokens
 

        uint256 collateralTokenValueInPrincipalToken = _valueOfUnderlying(
            collateralTokenBalance,
            collateralTokenExchangeRate()
        );

        uint256 totalValueInPrincipalTokens = collateralTokenValueInPrincipalToken +
                principalTokenBalance;

        if(totalValueInPrincipalTokens == 0) {return (0,0);}

   

        //i think i need more significant digits in my percent !?
        uint256 principalTotalAmountPercent = (_principalTokenAmountValue *
            10000 *
            1e18) / totalValueInPrincipalTokens;

       

        uint256 principalTokensToGive = (principalTokenBalance *
            principalTotalAmountPercent) / (1e18 * 10000);
        uint256 collateralTokensToGive = (collateralTokenBalance *
            principalTotalAmountPercent) / (1e18 * 10000);

      

        return (principalTokensToGive, collateralTokensToGive);
    }

    function getCollateralRequiredForPrincipalAmount(uint256 _principalAmount)
        public
        view
        returns (uint256)
    {
        return _getCollateralRequiredForPrincipalAmount(_principalAmount);
    }

    function _getCollateralRequiredForPrincipalAmount(uint256 _principalAmount)
        public
        view
        returns (uint256)
    {
        uint256 baseAmount = getCollateralTokensPricePerPrincipalTokens(
            _principalAmount
        );

        return baseAmount.percent(loanToValuePercent);
    }

    //this is priceToken1PerToken0 expanded by 1e18
    function _getUniswapV3TokenPairPrice() internal view returns (uint256) {
        // represents the square root of the price of token1 in terms of token0

        //(uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(UNISWAP_V3_POOL)
        //    .slot0();

        //twap interval = 20
        uint160 sqrtPriceX96 = getSqrtTwapX96(UNISWAP_V3_POOL, 20);

        // sqrtPrice is in X96 format so we scale it down to get the price
        // Also note that this price is a relative price between the two tokens in the pool
        // It's not a USD price
        uint256 price = ((uint256(sqrtPriceX96) * uint256(sqrtPriceX96))  /
           ( 2**96 ) );


        //this output is the price ratio expanded by 1e18
        return price  * 1e18 / (2**96) ;
    }

    // ---- TWAP 

     function getSqrtTwapX96(address uniswapV3Pool, uint32 twapInterval) public view returns (uint160 sqrtPriceX96) {
        if (twapInterval == 0) {
            // return the current price if twapInterval == 0
            (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(uniswapV3Pool).slot0();
        } else {
            uint32[] memory secondsAgos = new uint32[](2);
            secondsAgos[0] = twapInterval; // from (before)
            secondsAgos[1] = 0; // to (now)

            (int56[] memory tickCumulatives, ) = IUniswapV3Pool(uniswapV3Pool).observe(secondsAgos);

            // tick(imprecise as it's an integer) to price
            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
                int24((tickCumulatives[1] - tickCumulatives[0]) / twapInterval)
            );
        }
    }

    function getPriceX96FromSqrtPriceX96(uint160 sqrtPriceX96) public pure returns(uint256 priceX96) {
        return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
    }

    // -----




    function getCollateralTokensPricePerPrincipalTokens(
        uint256 collateralTokenAmount
    ) public view returns (uint256 principalTokenValue_) {
        bool principalTokenIsToken0 = true; //fix me

        uint256 pairPrice = _getUniswapV3TokenPairPrice();

        if (principalTokenIsToken0) {
            principalTokenValue_ = token1ToToken0(
                collateralTokenAmount,
                pairPrice
            );
        } else {
            principalTokenValue_ = token0ToToken1(
                collateralTokenAmount,
                pairPrice
            );
        }
    }

    //do i have to use the actual token decimals or can i just use 18 ?
    function token0ToToken1(uint256 amountToken0, uint256 priceToken1PerToken0)
        internal
        pure
        returns (uint256)
    {
        // Convert amountToken0 to the same decimals as Token1
        uint256 amountToken0WithToken1Decimals = amountToken0 * 10**18;
        // Now divide by the price to get the amount of token1
        return amountToken0WithToken1Decimals / priceToken1PerToken0;
    }

    function token1ToToken0(uint256 amountToken1, uint256 priceToken1PerToken0)
        internal
        pure
        returns (uint256)
    {
        // Multiply the amount of token1 by the price to get the amount in token0's units
        uint256 amountToken1InToken0 = amountToken1 * priceToken1PerToken0;
        // Now adjust for the decimal difference
        return amountToken1InToken0 / 10**18 ;
    }

   

    function repayLoanCallback(
        uint256 _bidId,
        address repayer,
        uint256 principalAmount,
        uint256 interestAmount
    ) external {
        //can use principal amt to increment amt paid back!! nice for math .
        totalPrincipalTokensRepaid += principalAmount;
        totalInterestCollected += interestAmount;
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

    function getRequiredCollateral(uint256 _principalAmount)
        public
        view
        returns (uint256 requiredCollateral_)
    {
        requiredCollateral_ = _getCollateralRequiredForPrincipalAmount(
            _principalAmount
        );
    }

    function getMarketId() external view returns (uint256) {
        return marketId;
    }

    function getMaxLoanDuration() external view returns (uint32) {
        return maxLoanDuration;
    }

    function getMinInterestRate() external view returns (uint16) {
        return minInterestRate;
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
        uint256 amountAvailable = totalPrincipalTokensCommitted -
            getTotalPrincipalTokensOutstandingInActiveLoans();

        return amountAvailable.percent(liquidityThresholdPercent);
    }
}
