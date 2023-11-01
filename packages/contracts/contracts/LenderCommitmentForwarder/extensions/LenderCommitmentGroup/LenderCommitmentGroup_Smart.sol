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

import {LoanRepaymentInterestCollector} from "./LoanRepaymentInterestCollector.sol";

import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import {CommitmentCollateralType, ISmartCommitment} from "../../../interfaces/ISmartCommitment.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
 

/*



If : 
        If  Lenders have to wait the entire maturity of the pool (expiration) and cant exist early, this becomes way simpler 
        If we use a price oracle for the 'PrincipalPerCollateralRatio  then this becomes way easier [Issue is the ratio cant be static for a long term]



        1. We could allow lender to exit early and we give them IOU tokens for their owed active loan collateral OR 
                we could just not allow lenders to exit early at all .  Allow lenders to just sell their share to someone else.  

        
 





How do we allocate  ?
  Active, Inactive, collateralValue 









1. Penalize early exits so exit only 



3. TVL = currentBalanceOfContract + currentBalanceOfInterestCollector + (totaltokensActivelyBeingBorrowed )( totalLentOutOutstanding   solve for this )  
3.1 Global Exchange Ratio (used to figure out how many shares to give per unit of input token) =  



total borrowed amount  - total repaid    





4. When you burn, you can specify the number of share tokens you want to burn OR you can specify the specific amt of tvl to withdraw 

5. see if i can implement exchange ratio copying off tvl token 



6. When withdrawing, should not be penalized because we use Oracle price to calculate actual TVL 
7. Use Noahs TToken logic for calculating exchange ratio 

https://github.com/teller-protocol/teller-protocol-v1/blob/develop/contracts/lending/ttoken/TToken_V3.sol



8. Research ticks (a mini pool within a pool)   (each can have a priceOracleRatio, each can have an expiration. )
9. ( would have to essentially have loops? )




////----


1. Use 50% forced max utilization ratio as initial game theory 
2. When pool shares are burned, give the lender : [ their pct shares *  ( currentPrincipalTokens in contract, totalCollateralShares, totalInterestCollected)   ] and later, they can burn the collateral shares for any collateral tokens that are in the contract. 
3. use noahs TToken contract as reference for ratios 
4.  Need price oracle bc we dont want to use maxPrincipalPerCollateral ratio as a static ideally 
5. have an LTV ratio 

Every time a lender deposits tokens, we can mint an equal amt of RepresentationToken



AAve utilization rate is 50% lets say 
no matter what , only 50 pct of 100 can be out on loan.




If a lender puts up 50,000 originally, im able to withdraw all my deposits.  Everyone else is in the hole until a borrower repays a loan 
If there isnt enough liquidity, you just cannot burn those shares. 

 
 
When a borrower comes and asks to use a particular principal to collateral ratio, a tick ,  we use THAT tick's gross tick liquidity value. 






Consider implementing eip-4626


*/





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
    address public immutable UNISWAP_V3_POOL; 
    
    bool private _initialized;
   
    LenderCommitmentGroupShares public poolSharesToken;
    LenderCommitmentGroupShares public collateralSharesToken;

    LoanRepaymentInterestCollector public interestCollector;



    IERC20 public principalToken;
    address public collateralTokenAddress;
    uint256 collateralTokenId;
    CommitmentCollateralType collateralTokenType;
    uint256 marketId;
    uint32 maxLoanDuration;
    uint16 minInterestRate;

    //uint256 maxPrincipalPerCollateralAmount;

   
    //this is all of the principal tokens that have been committed to this contract minus all that have been withdrawn.  This includes the tokens in this contract and lended out in active loans by this contract. 
    
    //run lots of tests in which tokens are donated to this contract to be uncommitted to make sure things done break 
    // tokens donated to this contract should be ignored? 
  
    uint256 public totalPrincipalTokensCommitted;         //this can be less than we expect if tokens are donated to the contract and withdrawn 
   
    uint256 public totalPrincipalTokensActivelyLended;

    uint256 public totalCollectedInterest;
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

        uint256 _collateralTokenId,
        CommitmentCollateralType _collateralTokenType, 

        uint256 _marketId,
        uint32 _maxLoanDuration,
        uint16 _minInterestRate,

        uint16 _liquidityThresholdPercent,
        uint16 _loanToValuePercent 

        //uint256 _maxPrincipalPerCollateralAmount //use oracle instead 

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

        liquidityThresholdPercent = _liquidityThresholdPercent;
        loanToValuePercent = _loanToValuePercent;

      //  maxPrincipalPerCollateralAmount = _maxPrincipalPerCollateralAmount;
       // _createInitialCommitment(_createCommitmentArgs);


       //set initial terms in storage from _createCommitmentArgs

        _deployPoolSharesToken();

        _deployCollateralSharesToken();

        _deployInterestCollector();


    }
 
 

    function _deployPoolSharesToken() internal {
       // uint256 principalTokenDecimals = principalToken.decimals();

        poolSharesToken =  new LenderCommitmentGroupShares(
            "PoolShares",
            "PSH",
            18   //may want this to equal the decimals of principal token !? 
        );

    }
    function _deployCollateralSharesToken() internal {
       // uint256 principalTokenDecimals = principalToken.decimals();

        collateralSharesToken =  new LenderCommitmentGroupShares(
            "CollateralShares",
            "CSH",
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
        onlyAfterInitialized
    {

        //transfers the primary principal token from msg.sender into this contract escrow 
        //gives 
        principalToken.transferFrom(msg.sender, address(this), _amount );
  

        //mint shares equal to _amount and give them to the shares recipient !!! 
        poolSharesToken.mint( _sharesRecipient,_amount);

        totalPrincipalTokensCommitted += _amount;
        principalTokensCommittedByLender[msg.sender] += _amount;

    }


   function acceptFundsForAcceptBid(
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

        totalPrincipalTokensActivelyLended += _principalAmount;

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


            //pull interest from interest collector 
                //
        uint256 collectedInterest = LoanRepaymentInterestCollector( interestCollector ).collectInterest();
        totalCollectedInterest += collectedInterest;


        //figure out the ratio of shares tokens that this is 
        uint256 poolSharesTotalSupplyBeforeBurn = poolSharesToken.totalSupply();

        //this DOES reduce total supply! This is necessary for correct math. 
        poolSharesToken.burn( msg.sender, _amountPoolSharesTokens );




/*

   This pool starts with principal tokens 

   Borrowers take those principal tokens (like uniswap)   -->   LoanValueTokens (fictitious)  (active loans where the lender is this contract) (this pool) 


    Eventually this pool has   a combo of principal tokens  and (activeloans)'Loanvaluetokens'  (teller loans who eventual value is pointing at this contract pool) 

   



*/


    /*
    The pool always has   CurrentBalance of Principal Tokens   + a currency balance of [Loan Value] Collateral IOU (tokens) 


    This contract starts with 100% of the outstanding 'collateral IOU tokens' 

     Doesnt make sense:    1. giving the lender their share of the CurrentBalance of principal tokens in this contract 
        2. giving the lender their share of "Collateral IOU' tokens  representing a share of the collateral outstanding to this contract.  



If a lender owns 10% of this pool equity -> they own  10% of current balance of principal tokens in here AND they own 10% of the (activeLoans) value [LoanvalueTokens]
  
  
            WHEN THEY GO TO EXIT  w 10% equity  
        1. it doesnt make sense to just give them   10% of the currenct balance of princpal tokens 
      2. it doesnt make sense to just give them   20% of the current balance of the contract ( 10% of tvl  in an example of 50pct utilization) 
   
   
    3.   Could give them 10% of the currenct balance of principal tokens  +  Somehow give them an IOU that represents 10% of the active loan value 
  
  
  
    
  
    */
 

        /*  
        The fraction of shares that was just burned has 
        a numerator of _amount and 
        a denominator of sharesTotalSupplyBeforeBurn !
        */

        /*
            In this flow, lenders who withdraw first are able to claim the liquid tokens first 
            while the illiquid assets remain withdrawable by the remaining lenders at a later time. 

        */


       // uint256 principalTokenBalance = principalToken.balanceOf(address(this));



            //hopefully this is correct ?  have to make sure it isnt negative tho ? 
       // uint256 totalLendedTokensRepaidFromLending = (principalTokenBalance + totalPrincipalTokensUncommitted + totalPrincipalTokensActivelyLended) - (totalPrincipalTokensCommitted + totalCollectedInterest );
 
 
       // uint256 principalTokenEquityAmount = principalTokenBalance + totalPrincipalTokensActivelyLended - totalLendedTokensRepaidFromLending ;

       
        uint256 netCommittedTokens = totalPrincipalTokensCommitted; 

      

        uint256 principalTokenEquityAmountSimple =  totalPrincipalTokensCommitted + totalCollectedInterest - ( totalInterestWithdrawn);

        uint256 principalTokenAmountToWithdraw = principalTokenEquityAmountSimple * _amountPoolSharesTokens / poolSharesTotalSupplyBeforeBurn;
        uint256 tokensToUncommit = netCommittedTokens * _amountPoolSharesTokens / poolSharesTotalSupplyBeforeBurn;

        totalPrincipalTokensCommitted -= tokensToUncommit;
       // totalPrincipalTokensUncommitted += tokensToUncommit;

        totalInterestWithdrawn += principalTokenAmountToWithdraw - tokensToUncommit;


        //totalPrincipalTokensCommitted -= principalTokenAmountToWithdraw;
        principalTokensCommittedByLender[msg.sender] -= principalTokenAmountToWithdraw;
        
        principalToken.transfer( _recipient, principalTokenAmountToWithdraw );


        //also mint collateral token shares !!  or give them out . 
        
  
    }


/*
consider passing in both token addresses and then get pool address from that 
*/  

    //this depends on oracle price 

    function getMaxPrincipalPerCollateralAmount(  ) public returns (uint256) {


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


    function getInterestCollector() public view returns (address) {

        return interestCollector;
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


      uint256 maxPrincipalPerCollateralAmount = getMaxPrincipalPerCollateralAmount( );

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


        uint256 amountAvailable = totalPrincipalTokensCommitted.percent( liquidityThresholdPercent )
         - totalPrincipalTokensActivelyLended
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
