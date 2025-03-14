import { Testable } from "../Testable.sol";

import { LenderCommitmentGroup_Smart_V2_Override } from "./LenderCommitmentGroup_Smart_V2_Override.sol";

import {TestERC20Token} from "../tokens/TestERC20Token.sol";

import {MarketRegistry} from "../../contracts/MarketRegistry.sol";
import {SmartCommitmentForwarder} from "../../contracts/LenderCommitmentForwarder/SmartCommitmentForwarder.sol";
import {TellerV2SolMock} from "../../contracts/mock/TellerV2SolMock.sol";
import {UniswapV3PoolMock} from "../../contracts/mock/uniswap/UniswapV3PoolMock.sol";
import {UniswapV3FactoryMock} from "../../contracts/mock/uniswap/UniswapV3FactoryMock.sol";
import { PaymentType, PaymentCycleType } from "../../contracts/libraries/V2Calculations.sol";
import { LoanDetails, Payment, BidState , Bid, Terms } from "../../contracts/TellerV2Storage.sol";

import { ILenderCommitmentGroup_V2 } from "../../contracts/interfaces/ILenderCommitmentGroup_V2.sol";
import { IUniswapPricingLibrary } from "../../contracts/interfaces/IUniswapPricingLibrary.sol";
import { LenderCommitmentGroupShares_V2 } from "../../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroupShares_V2.sol";

import {ProtocolPausingManager} from "../../contracts/pausing/ProtocolPausingManager.sol";

import "lib/forge-std/src/console.sol";
import "lib/forge-std/src/Vm.sol";

// Helper contract to simulate a user
contract User {}

contract LenderCommitmentGroup_Smart_V2_Test is Testable {
    constructor() {}

    User private extensionContract;

    User private borrower;
    User private lender;
    User private liquidator;

    TestERC20Token principalToken;
    TestERC20Token collateralToken;

     LenderCommitmentGroup_Smart_V2_Override lenderCommitmentGroupSmartV2;

    MarketRegistry _marketRegistry;
    TellerV2SolMock _tellerV2;
    SmartCommitmentForwarder _smartCommitmentForwarder;
    UniswapV3PoolMock _uniswapV3Pool;
    UniswapV3FactoryMock _uniswapV3Factory;
    
    ProtocolPausingManager _protocolPausingManager;

    function setUp() public {
        borrower = new User();
        lender = new User();
        liquidator = new User();

        _tellerV2 = new TellerV2SolMock();
        _marketRegistry = new MarketRegistry();
        _smartCommitmentForwarder = new SmartCommitmentForwarder(
            address(_tellerV2), address(_marketRegistry));
         
        _uniswapV3Pool = new UniswapV3PoolMock();

        _uniswapV3Factory = new UniswapV3FactoryMock();
        _uniswapV3Factory.setPoolMock(address(_uniswapV3Pool));

        _protocolPausingManager = new ProtocolPausingManager();
        _protocolPausingManager.initialize();

        _tellerV2.setProtocolPausingManager(address(_protocolPausingManager));

        principalToken = new TestERC20Token("wrappedETH", "WETH", 1e24, 18);
        collateralToken = new TestERC20Token("PEPE", "pepe", 1e24, 18);

        principalToken.transfer(address(lender), 1e18);
        collateralToken.transfer(address(borrower), 1e18);
        principalToken.transfer(address(liquidator), 1e18);

        _uniswapV3Pool.set_mockToken0(address(principalToken));
        _uniswapV3Pool.set_mockToken1(address(collateralToken));

          lenderCommitmentGroupSmartV2 = new LenderCommitmentGroup_Smart_V2_Override(
            address(_tellerV2),
            address(_smartCommitmentForwarder),
            address(_uniswapV3Factory)
        );
    }

    function initialize_group_contract() public {
        address _principalTokenAddress = address(principalToken);
        address _collateralTokenAddress = address(collateralToken);
        uint256 _marketId = 1;
        uint32 _maxLoanDuration = 5000000;
        uint16 _interestRateLowerBound = 0;
        uint16 _interestRateUpperBound = 800;
        uint16 _liquidityThresholdPercent = 10000;
        uint16 _collateralRatio = 10000;
       // uint24 _uniswapPoolFee = 3000;
       // uint32 _twapInterval = 5;

         ILenderCommitmentGroup_V2.CommitmentGroupConfig memory groupConfig = ILenderCommitmentGroup_V2.CommitmentGroupConfig({
            principalTokenAddress: _principalTokenAddress,
            collateralTokenAddress: _collateralTokenAddress,
            marketId: _marketId,
            maxLoanDuration: _maxLoanDuration,
            interestRateLowerBound: _interestRateLowerBound,
            interestRateUpperBound: _interestRateUpperBound,
            liquidityThresholdPercent: _liquidityThresholdPercent,
            collateralRatio: _collateralRatio
           // uniswapPoolFee: _uniswapPoolFee,
           // twapInterval: _twapInterval
        });

          bool zeroForOne = false;
          uint32 twapInterval = 0;


          IUniswapPricingLibrary.PoolRouteConfig
            memory routeConfig = IUniswapPricingLibrary.PoolRouteConfig({
                pool: address(_uniswapV3Pool),
                zeroForOne: zeroForOne,
                twapInterval: twapInterval,
                token0Decimals: 18,
                token1Decimals: 18
            });


       IUniswapPricingLibrary.PoolRouteConfig[]
            memory routesConfig = new IUniswapPricingLibrary.PoolRouteConfig[](
                1
            );

        routesConfig[0] = routeConfig; 



         LenderCommitmentGroupShares_V2 newSharesToken = new LenderCommitmentGroupShares_V2();
        newSharesToken.initialize();
        newSharesToken.transferOwnership(address(lenderCommitmentGroupSmartV2));


        
        address _poolSharesToken = lenderCommitmentGroupSmartV2.initialize(
            groupConfig,
            routesConfig,
            address(newSharesToken)
        );  

        lenderCommitmentGroupSmartV2.mock_setFirstDepositMade(true);
    }



    function test_initialize() public {
        address _principalTokenAddress = address(principalToken);
        address _collateralTokenAddress = address(collateralToken);
        uint256 _marketId = 1;
        uint32 _maxLoanDuration = 5000000;
        uint16 _interestRateLowerBound = 100;
        uint16 _interestRateUpperBound = 800;
        uint16 _liquidityThresholdPercent = 10000;
        uint16 _collateralRatio = 10000;

        ILenderCommitmentGroup_V2.CommitmentGroupConfig memory groupConfig = ILenderCommitmentGroup_V2.CommitmentGroupConfig({
            principalTokenAddress: _principalTokenAddress,
            collateralTokenAddress: _collateralTokenAddress,
            marketId: _marketId,
            maxLoanDuration: _maxLoanDuration,
            interestRateLowerBound: _interestRateLowerBound,
            interestRateUpperBound: _interestRateUpperBound,
            liquidityThresholdPercent: _liquidityThresholdPercent,
            collateralRatio: _collateralRatio
        });

        bool zeroForOne = false;
        uint32 twapInterval = 0;

        IUniswapPricingLibrary.PoolRouteConfig
            memory routeConfig = IUniswapPricingLibrary.PoolRouteConfig({
                pool: address(_uniswapV3Pool),
                zeroForOne: zeroForOne,
                twapInterval: twapInterval,
                token0Decimals: 18,
                token1Decimals: 18
            });

        IUniswapPricingLibrary.PoolRouteConfig[]
            memory routesConfig = new IUniswapPricingLibrary.PoolRouteConfig[](
                1
            );

        routesConfig[0] = routeConfig; 
        
        // Create a new token for this test
        LenderCommitmentGroupShares_V2 newSharesToken = new LenderCommitmentGroupShares_V2();
        newSharesToken.initialize();
        newSharesToken.transferOwnership(address(lenderCommitmentGroupSmartV2));

        address _poolSharesToken = lenderCommitmentGroupSmartV2.initialize(
            groupConfig,
            routesConfig,
            address(newSharesToken)
        );
    }

    // ERC4626 Vault Tests
    function test_erc4626_deposit() public {
        initialize_group_contract();
        lenderCommitmentGroupSmartV2.set_mockSharesExchangeRate(1e36);

        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupSmartV2), 1000000);

        vm.prank(address(lender));
        uint256 sharesAmount = lenderCommitmentGroupSmartV2.deposit(1000000, address(lender));

        uint256 expectedSharesAmount = 1000000;
        assertEq(
            sharesAmount,
            expectedSharesAmount,
            "Received an unexpected amount of shares"
        );
    }

    function test_erc4626_mint() public {
        initialize_group_contract();
        lenderCommitmentGroupSmartV2.set_mockSharesExchangeRate(1e36);

        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupSmartV2), 1000000);

        vm.prank(address(lender));
        uint256 assetsAmount = lenderCommitmentGroupSmartV2.mint(1000000, address(lender));

        uint256 expectedAssetsAmount = 1000000;
        assertEq(
            assetsAmount,
            expectedAssetsAmount,
            "Used an unexpected amount of assets"
        );
    }
    
    function test_erc4626_redeem() public {
        principalToken.transfer(address(lenderCommitmentGroupSmartV2), 1e18);
        
        initialize_group_contract();
        lenderCommitmentGroupSmartV2.set_mockSharesExchangeRate(1e36);
        
        lenderCommitmentGroupSmartV2.set_totalPrincipalTokensCommitted(1000000);
        
        // Mint shares to lender
        uint256 sharesAmount = 1000000;
        lenderCommitmentGroupSmartV2.mock_mintShares(address(lender), sharesAmount);
        
        vm.prank(address(lender));
        uint256 assetsReceived = lenderCommitmentGroupSmartV2.redeem(
            sharesAmount,
            address(lender),
            address(lender)
        );
        
        uint256 expectedAssetsReceived = 1000000;
        assertEq(
            assetsReceived,
            expectedAssetsReceived,
            "Received an unexpected amount of assets"
        );
    }
    
    function test_erc4626_withdraw() public {
        principalToken.transfer(address(lenderCommitmentGroupSmartV2), 1e18);
        
        initialize_group_contract();
        lenderCommitmentGroupSmartV2.set_mockSharesExchangeRate(1e36);
        
        lenderCommitmentGroupSmartV2.set_totalPrincipalTokensCommitted(1000000);
        
        // Mint shares to lender
        uint256 sharesAmount = 1000000;
        lenderCommitmentGroupSmartV2.mock_mintShares(address(lender), sharesAmount);
        
        vm.prank(address(lender));
        uint256 sharesRedeemedAmount = lenderCommitmentGroupSmartV2.withdraw(
            1000000,
            address(lender),
            address(lender)
        );
        
        uint256 expectedSharesRedeemed = 1000000;
        assertEq(
            sharesRedeemedAmount,
            expectedSharesRedeemed,
            "Burned an unexpected amount of shares"
        );
    }

    function test_erc4626_accounting() public {
        initialize_group_contract();
        
        lenderCommitmentGroupSmartV2.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupSmartV2.set_totalInterestCollected(500000);
        
        // Test totalAssets()
        uint256 totalAssets = lenderCommitmentGroupSmartV2.totalAssets();
        // totalAssets calls getPoolTotalEstimatedValue internally
        assertEq(totalAssets, 1500000, "Incorrect total assets calculation");
        
        // Test convertToShares/convertToAssets with 1:1 exchange rate
        lenderCommitmentGroupSmartV2.set_mockSharesExchangeRate(1e36);
        
        uint256 shares = lenderCommitmentGroupSmartV2.convertToShares(1000);
        assertEq(shares, 1000, "Incorrect shares conversion");
        
        uint256 assets = lenderCommitmentGroupSmartV2.convertToAssets(1000);
        assertEq(assets, 1000, "Incorrect assets conversion");
        
        // Test with 2:1 exchange rate (1 share = 2 assets)
        lenderCommitmentGroupSmartV2.set_mockSharesExchangeRate(2 * 1e36);
        
        shares = lenderCommitmentGroupSmartV2.convertToShares(1000);
        assertEq(shares, 500, "Incorrect shares conversion with 2:1 rate");
        
        assets = lenderCommitmentGroupSmartV2.convertToAssets(500);
        assertEq(assets, 1000, "Incorrect assets conversion with 2:1 rate");
    }

    function test_acceptFundsForAcceptBid() public {
        lenderCommitmentGroupSmartV2.set_mock_requiredCollateralAmount(100);
        
        principalToken.transfer(address(lenderCommitmentGroupSmartV2), 1e18);
        collateralToken.transfer(address(lenderCommitmentGroupSmartV2), 1e18);

        initialize_group_contract();

        lenderCommitmentGroupSmartV2.set_totalPrincipalTokensCommitted(1000000);

        uint256 principalAmount = 50;
        uint256 collateralAmount = 100;

        address collateralTokenAddress = address(
            lenderCommitmentGroupSmartV2.collateralToken()
        );
        uint256 collateralTokenId = 0;

        uint32 loanDuration = 5000000;
        uint16 interestRate = 100;

        uint256 bidId = 0;

        // submit bid 
        TellerV2SolMock(_tellerV2).submitBid( 
            address(principalToken),
            0,
            principalAmount,
            loanDuration,
            interestRate,
            "",
            address(this)
        );

        vm.prank(address(_smartCommitmentForwarder));
        lenderCommitmentGroupSmartV2.acceptFundsForAcceptBid(
            address(borrower),
            bidId,
            principalAmount,
            collateralAmount,
            collateralTokenAddress,
            collateralTokenId,
            loanDuration,
            interestRate
        );
    }

    function test_acceptFundsForAcceptBid_insufficientCollateral() public {
        lenderCommitmentGroupSmartV2.set_mock_requiredCollateralAmount(100);

        principalToken.transfer(address(lenderCommitmentGroupSmartV2), 1e18);
        collateralToken.transfer(address(lenderCommitmentGroupSmartV2), 1e18);

        initialize_group_contract();

        lenderCommitmentGroupSmartV2.set_totalPrincipalTokensCommitted(1000000);

        uint256 principalAmount = 100;
        uint256 collateralAmount = 0;

        address collateralTokenAddress = address(
            lenderCommitmentGroupSmartV2.collateralToken()
        );
        uint256 collateralTokenId = 0;

        uint32 loanDuration = 5000000;
        uint16 interestRate = 100;

        uint256 bidId = 0;

        // We expect a revert with the message "C" (for Collateral error)
        vm.expectRevert(bytes("C"));
        vm.prank(address(_smartCommitmentForwarder));
        lenderCommitmentGroupSmartV2.acceptFundsForAcceptBid(
            address(borrower),
            bidId,
            principalAmount,
            collateralAmount,
            collateralTokenAddress,
            collateralTokenId,
            loanDuration,
            interestRate
        );
    }

    function test_repayLoanCallback() public {
        uint256 principalAmount = 100;
        uint256 interestAmount = 50;
        address repayer = address(borrower);

        uint256 bidId = 0;

        lenderCommitmentGroupSmartV2.mock_setBidActive(bidId);
        
        vm.prank(address(_tellerV2));
        lenderCommitmentGroupSmartV2.repayLoanCallback(
            bidId,
            address(repayer),
            principalAmount,
            interestAmount
        );
    }

    function test_repayLoanCallback_bid_not_active() public {
        uint256 principalAmount = 100;
        uint256 interestAmount = 50;
        address repayer = address(borrower);

        uint256 bidId = 0;

        vm.expectRevert(bytes("BNA"));
        vm.prank(address(_tellerV2));
        lenderCommitmentGroupSmartV2.repayLoanCallback(
            bidId,
            address(repayer),
            principalAmount,
            interestAmount
        );
    }

    function test_liquidation_bid_not_active() public {
        initialize_group_contract();

        vm.warp(1e10);

        uint256 marketId = 0; 
        uint256 principalAmount = 100;
        uint32 loanDuration = 500000;
        uint16 interestRate = 50;
        
        // submit bid 
        uint256 bidId = TellerV2SolMock(_tellerV2).submitBid( 
            address(principalToken),
            marketId,
            principalAmount,
            loanDuration,
            interestRate,
            "",
            address(borrower)
        );

        vm.prank(address(lender));
        principalToken.approve(address(_tellerV2), 1000000);

        vm.prank(address(lender));
        TellerV2SolMock(_tellerV2).lenderAcceptBid(bidId);
        
        vm.warp(1e20);

        int256 tokenAmountDifference = 10000;

        vm.expectRevert(bytes("BNA"));
        lenderCommitmentGroupSmartV2.liquidateDefaultedLoanWithIncentive(
            bidId,
            tokenAmountDifference
        );
    }
    
    function test_liquidation_handles_partially_repaid_loan_scenarioA() public {
        initialize_group_contract();

        vm.warp(10000000000);

        uint256 marketId = 0; 
        uint256 principalAmount = 900;
        uint32 loanDuration = 500000;
        uint16 interestRate = 50;
        
        // submit bid 
        uint256 bidId = TellerV2SolMock(_tellerV2).submitBid( 
            address(principalToken),
            marketId,
            principalAmount,
            loanDuration,
            interestRate,
            "",
            address(borrower)
        );

        vm.prank(address(lender));
        principalToken.approve(address(_tellerV2), 1000000);

        vm.prank(address(lender));
        TellerV2SolMock(_tellerV2).lenderAcceptBid(bidId);

        lenderCommitmentGroupSmartV2.set_mockBidAsActiveForGroup(bidId, true);
        lenderCommitmentGroupSmartV2.set_mockActiveBidsAmountDueRemaining(bidId, principalAmount);

        uint256 principalTokensCommitted = 4000;
        lenderCommitmentGroupSmartV2.set_totalPrincipalTokensCommitted(principalTokensCommitted);
        
        // Mock the loan as defaulted
        _tellerV2.mock_setLoanDefaultTimestamp(block.timestamp - 1000);
        
        // Set up a high incentive for liquidation (positive value = liquidator pays extra)
        lenderCommitmentGroupSmartV2.mock_setMinimumAmountDifferenceToCloseDefaultedLoan(500);
        
        // Approve tokens for liquidator
        vm.prank(address(liquidator));
        principalToken.approve(address(lenderCommitmentGroupSmartV2), principalAmount + 500);
        
        // Liquidate the loan
        vm.prank(address(liquidator));
        lenderCommitmentGroupSmartV2.liquidateDefaultedLoanWithIncentive(
            bidId,
            500
        );
    }

    function test_getMinimumAmountDifferenceToCloseDefaultedLoan() public {
        initialize_group_contract();

        uint256 bidId = 0;
        uint256 amountDue = 500;

        _tellerV2.mock_setLoanDefaultTimestamp(block.timestamp);
   
        vm.warp(10000);
        uint256 loanDefaultTimestamp = block.timestamp - 2000; //sim that loan defaulted 2000 seconds ago 

        int256 min_amount = lenderCommitmentGroupSmartV2.super_getMinimumAmountDifferenceToCloseDefaultedLoan(
            amountDue,
            loanDefaultTimestamp
        );

        int256 expectedMinAmount = 3720; //based on loanDefaultTimestamp gap 
        assertEq(min_amount, expectedMinAmount, "min_amount unexpected");
    }

    function test_getMinimumAmountDifferenceToCloseDefaultedLoan_zero_time() public {
        initialize_group_contract();

        uint256 bidId = 0;
        uint256 amountDue = 500;

        _tellerV2.mock_setLoanDefaultTimestamp(block.timestamp);
   
        vm.warp(10000);
        uint256 loanDefaultTimestamp = block.timestamp; //sim that loan defaulted 0 seconds ago 

        vm.expectRevert(bytes("LDT"));
        int256 min_amount = lenderCommitmentGroupSmartV2.super_getMinimumAmountDifferenceToCloseDefaultedLoan(
            amountDue,
            loanDefaultTimestamp
        );
    }

    function test_getMinimumAmountDifferenceToCloseDefaultedLoan_full_time() public {
        initialize_group_contract();

        uint256 bidId = 0;
        uint256 amountDue = 500;

        _tellerV2.mock_setLoanDefaultTimestamp(block.timestamp);
   
        vm.warp(100000);
        uint256 loanDefaultTimestamp = block.timestamp - 22000; //sim that loan defaulted 22000 seconds ago 

        int256 min_amount = lenderCommitmentGroupSmartV2.super_getMinimumAmountDifferenceToCloseDefaultedLoan(
            amountDue,
            loanDefaultTimestamp
        );

        int256 expectedMinAmount = 2720; //based on loanDefaultTimestamp gap 
        assertEq(min_amount, expectedMinAmount, "min_amount unexpected");
    }

    function test_get_shares_exchange_rate_scenario_A() public {
        initialize_group_contract();

        lenderCommitmentGroupSmartV2.set_totalInterestCollected(0);
        lenderCommitmentGroupSmartV2.set_totalPrincipalTokensCommitted(5000000);

        uint256 rate = lenderCommitmentGroupSmartV2.super_sharesExchangeRate();
        assertEq(rate, 1e36, "unexpected sharesExchangeRate");
    }

    function test_get_shares_exchange_rate_scenario_B() public {
        initialize_group_contract();

        lenderCommitmentGroupSmartV2.set_totalInterestCollected(1000000);
        lenderCommitmentGroupSmartV2.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupSmartV2.set_totalPrincipalTokensWithdrawn(1000000);

        uint256 rate = lenderCommitmentGroupSmartV2.super_sharesExchangeRate();
        assertEq(rate, 1e36, "unexpected sharesExchangeRate");
    }

    function test_get_shares_exchange_rate_scenario_C() public {
        initialize_group_contract();

        lenderCommitmentGroupSmartV2.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupSmartV2.set_totalInterestCollected(1000000);

        uint256 sharesAmount = 500000;
        lenderCommitmentGroupSmartV2.mock_mintShares(
            address(lender),
            sharesAmount
        );

        uint256 poolTotalEstimatedValue = lenderCommitmentGroupSmartV2.public_getPoolTotalEstimatedValue();
        assertEq(poolTotalEstimatedValue, 2 * 1000000, "unexpected poolTotalEstimatedValue");

        uint256 rate = lenderCommitmentGroupSmartV2.super_sharesExchangeRate();
        assertEq(rate, 4 * 1e36, "unexpected sharesExchangeRate");
    }

    function test_get_shares_exchange_rate_after_default_liquidation_A() public {
        initialize_group_contract();

        lenderCommitmentGroupSmartV2.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupSmartV2.set_totalInterestCollected(1000000);
        lenderCommitmentGroupSmartV2.set_tokenDifferenceFromLiquidations(-1000000);

        uint256 sharesAmount = 1000000;
        lenderCommitmentGroupSmartV2.mock_mintShares(
            address(lender),
            sharesAmount
        );

        uint256 poolTotalEstimatedValue = lenderCommitmentGroupSmartV2.public_getPoolTotalEstimatedValue();
        assertEq(poolTotalEstimatedValue, 1 * 1000000, "unexpected poolTotalEstimatedValue");

        uint256 rate = lenderCommitmentGroupSmartV2.super_sharesExchangeRate();
        assertEq(rate, 1 * 1e36, "unexpected sharesExchangeRate");
    }

    function test_get_shares_exchange_rate_after_default_liquidation_B() public {
        initialize_group_contract();

        lenderCommitmentGroupSmartV2.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupSmartV2.set_tokenDifferenceFromLiquidations(-500000);

        uint256 sharesAmount = 1000000;
        lenderCommitmentGroupSmartV2.mock_mintShares(
            address(lender),
            sharesAmount
        );

        uint256 poolTotalEstimatedValue = lenderCommitmentGroupSmartV2.public_getPoolTotalEstimatedValue();
        assertEq(poolTotalEstimatedValue, 1 * 500000, "unexpected poolTotalEstimatedValue");

        uint256 rate = lenderCommitmentGroupSmartV2.super_sharesExchangeRate();
        assertEq(rate, 1e36 / 2, "unexpected sharesExchangeRate");
    }
    
    // Test the ERC4626 max methods
    function test_erc4626_max_methods() public {
        initialize_group_contract();
        
        // Test maxDeposit and maxMint when not paused
        uint256 maxDeposit = lenderCommitmentGroupSmartV2.maxDeposit(address(lender));
        assertEq(maxDeposit, type(uint256).max, "Incorrect maxDeposit when not paused");
        
        uint256 maxMint = lenderCommitmentGroupSmartV2.maxMint(address(lender));
        assertEq(maxMint, type(uint256).max, "Incorrect maxMint when not paused");
        
        // Mint shares to lender
        uint256 sharesAmount = 1000000;
        lenderCommitmentGroupSmartV2.mock_mintShares(address(lender), sharesAmount);
        
        // Test maxWithdraw and maxRedeem
        principalToken.transfer(address(lenderCommitmentGroupSmartV2), 800000);
        lenderCommitmentGroupSmartV2.set_mockSharesExchangeRate(1e36);
        
        uint256 maxWithdraw = lenderCommitmentGroupSmartV2.maxWithdraw(address(lender));
        assertEq(maxWithdraw, 800000, "Incorrect maxWithdraw");
        
        uint256 maxRedeem = lenderCommitmentGroupSmartV2.maxRedeem(address(lender));
        assertEq(maxRedeem, 800000, "Incorrect maxRedeem");
        
        // Test when paused
        vm.prank(address(_tellerV2));
        lenderCommitmentGroupSmartV2.pauseLendingPool();
        
        maxDeposit = lenderCommitmentGroupSmartV2.maxDeposit(address(lender));
        assertEq(maxDeposit, 0, "Incorrect maxDeposit when paused");
        
        maxMint = lenderCommitmentGroupSmartV2.maxMint(address(lender));
        assertEq(maxMint, 0, "Incorrect maxMint when paused");
        
        maxWithdraw = lenderCommitmentGroupSmartV2.maxWithdraw(address(lender));
        assertEq(maxWithdraw, 0, "Incorrect maxWithdraw when paused");
        
        maxRedeem = lenderCommitmentGroupSmartV2.maxRedeem(address(lender));
        assertEq(maxRedeem, 0, "Incorrect maxRedeem when paused");
    }
    
    // Test the ERC4626 preview methods
    function test_erc4626_preview_methods() public {
        initialize_group_contract();
        lenderCommitmentGroupSmartV2.set_mockSharesExchangeRate(1e36);
        
        // Test with 1:1 exchange rate
        uint256 previewDeposit = lenderCommitmentGroupSmartV2.previewDeposit(1000);
        assertEq(previewDeposit, 1000, "Incorrect previewDeposit");
        
        uint256 previewMint = lenderCommitmentGroupSmartV2.previewMint(1000);
        assertEq(previewMint, 1000, "Incorrect previewMint");
        
        uint256 previewWithdraw = lenderCommitmentGroupSmartV2.previewWithdraw(1000);
        assertEq(previewWithdraw, 1000, "Incorrect previewWithdraw");
        
        uint256 previewRedeem = lenderCommitmentGroupSmartV2.previewRedeem(1000);
        assertEq(previewRedeem, 1000, "Incorrect previewRedeem");
        
        // Test with 2:1 exchange rate (1 share = 2 assets)
        lenderCommitmentGroupSmartV2.set_mockSharesExchangeRate(2 * 1e36);
        
        previewDeposit = lenderCommitmentGroupSmartV2.previewDeposit(1000);
        assertEq(previewDeposit, 500, "Incorrect previewDeposit with 2:1 rate");
        
        previewMint = lenderCommitmentGroupSmartV2.previewMint(500);
        assertEq(previewMint, 1000, "Incorrect previewMint with 2:1 rate");
        
        previewWithdraw = lenderCommitmentGroupSmartV2.previewWithdraw(1000);
        assertEq(previewWithdraw, 500, "Incorrect previewWithdraw with 2:1 rate");
        
        previewRedeem = lenderCommitmentGroupSmartV2.previewRedeem(500);
        assertEq(previewRedeem, 1000, "Incorrect previewRedeem with 2:1 rate");
    }
    
    // Test pausing functionality
    function test_pause_unpause() public {
        initialize_group_contract();
        
        // Set up protocol pauser
        address pausingManager = _tellerV2.getProtocolPausingManager();
        
        // Test pause
        vm.prank(address(_tellerV2));
        lenderCommitmentGroupSmartV2.pauseLendingPool();
        assertTrue(lenderCommitmentGroupSmartV2.paused(), "Contract should be paused");
        
        // Test unpause
        vm.prank(address(_tellerV2));
        lenderCommitmentGroupSmartV2.unpauseLendingPool();
        assertFalse(lenderCommitmentGroupSmartV2.paused(), "Contract should be unpaused");
        
        // Verify lastUnpausedAt was set
        uint256 lastUnpausedAt = lenderCommitmentGroupSmartV2.getLastUnpausedAt();
        assertEq(lastUnpausedAt, block.timestamp, "lastUnpausedAt not set correctly");
    }
}