import { Testable } from "../Testable.sol";

import { LenderCommitmentGroup_Pool_V2_Override } from "./LenderCommitmentGroup_Pool_V2_Override.sol";

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
 
import {ProtocolPausingManager} from "../../contracts/pausing/ProtocolPausingManager.sol";

import "lib/forge-std/src/console.sol";
import "lib/forge-std/src/Vm.sol";

// Helper contract to simulate a user
contract User {}

contract LenderCommitmentGroup_Pool_V2_Test is Testable {
    constructor() {}

    User private extensionContract;

    User private borrower;
    User private lender;
    User private liquidator;

    TestERC20Token principalToken;
    TestERC20Token collateralToken;

     LenderCommitmentGroup_Pool_V2_Override lenderCommitmentGroupSmartV2;
     

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

          lenderCommitmentGroupSmartV2 = new LenderCommitmentGroup_Pool_V2_Override(
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


 
         lenderCommitmentGroupSmartV2.initialize(
            groupConfig,
            routesConfig 
           
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
       

        lenderCommitmentGroupSmartV2.initialize(
            groupConfig,
            routesConfig 
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
        
         vm.warp( 1e6 );

        // Mint shares to lender
        uint256 sharesAmount = 1000000;
        vm.prank(address(lenderCommitmentGroupSmartV2));
        lenderCommitmentGroupSmartV2.force_mint_shares(address(lender), sharesAmount);
            

        vm.warp( 1e7 );


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
            
        vm.warp(1e6);

        // Mint shares to lender
        uint256 sharesAmount = 1000000;
         vm.prank(address(lenderCommitmentGroupSmartV2));
        lenderCommitmentGroupSmartV2.force_mint_shares(address(lender), sharesAmount);

        vm.warp(1e7);
        
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
        
         vm.prank(address(lenderCommitmentGroupSmartV2));
        lenderCommitmentGroupSmartV2.force_mint_shares(address(lender), sharesAmount);


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
    
         vm.prank(address(lenderCommitmentGroupSmartV2));
        lenderCommitmentGroupSmartV2.force_mint_shares(address(lender), sharesAmount);


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
 
         vm.prank(address(lenderCommitmentGroupSmartV2));
        lenderCommitmentGroupSmartV2.force_mint_shares(address(lender), sharesAmount);


        uint256 poolTotalEstimatedValue = lenderCommitmentGroupSmartV2.public_getPoolTotalEstimatedValue();
        assertEq(poolTotalEstimatedValue, 1 * 500000, "unexpected poolTotalEstimatedValue");

        uint256 rate = lenderCommitmentGroupSmartV2.super_sharesExchangeRate();
        assertEq(rate, 1e36 / 2, "unexpected sharesExchangeRate");
    }
    
     
    
    // Test pausing functionality
    function test_pause_unpause() public {
      initialize_group_contract();

      // Get the protocol pausing manager
      address pausingManager = _tellerV2.getProtocolPausingManager();

      // Grant pauser role to _tellerV2
      vm.prank(address(this));  // The test contract is likely the owner of _protocolPausingManager
      _protocolPausingManager.addPauser(address(_tellerV2));

      // Now test pause/unpause
      vm.prank(address(_tellerV2));
      lenderCommitmentGroupSmartV2.pauseLendingPool();
      assertTrue(lenderCommitmentGroupSmartV2.paused(), "Contract should be paused");

      vm.prank(address(_tellerV2));
      lenderCommitmentGroupSmartV2.unpauseLendingPool();
      assertFalse(lenderCommitmentGroupSmartV2.paused(), "Contract should be unpaused");

      // Verify lastUnpausedAt was set
      uint256 lastUnpausedAt = lenderCommitmentGroupSmartV2.getLastUnpausedAt();
      assertEq(lastUnpausedAt, block.timestamp, "lastUnpausedAt not set correctly");
    }
    
   


      // Test previewDeposit function with different exchange rates
      function test_previewDeposit() public {
          initialize_group_contract();
          
          // Test with 1:1 exchange rate
          lenderCommitmentGroupSmartV2.set_mockSharesExchangeRate(1e36);
          
          uint256 assets = 1000000;
          uint256 expectedShares = 1000000;
          
          uint256 shares = lenderCommitmentGroupSmartV2.previewDeposit(assets);
          assertEq(shares, expectedShares, "previewDeposit should return correct shares at 1:1 rate");
          
          // Test with 2:1 exchange rate (1 share = 2 assets)
          lenderCommitmentGroupSmartV2.set_mockSharesExchangeRate(2 * 1e36);
          
          expectedShares = 500000; // 1000000 assets / 2 = 500000 shares
          shares = lenderCommitmentGroupSmartV2.previewDeposit(assets);
          assertEq(shares, expectedShares, "previewDeposit should return correct shares at 2:1 rate");
          
          // Test with 1:2 exchange rate (2 shares = 1 asset)
          lenderCommitmentGroupSmartV2.set_mockSharesExchangeRate(5e35); // 0.5 * 1e36
          
          expectedShares = 2000000; // 1000000 assets * 2 = 2000000 shares
          shares = lenderCommitmentGroupSmartV2.previewDeposit(assets);
          assertEq(shares, expectedShares, "previewDeposit should return correct shares at 1:2 rate");
      }
      

      function test_sharesExchangeRate() public {

 

        
      }




      // Test previewMint function with different exchange rates
      function test_previewMint() public {
          initialize_group_contract();
          
          // Test with 1:1 exchange rate
          lenderCommitmentGroupSmartV2.set_mockSharesExchangeRate(1e36);
          
          uint256 shares = 1000000;
          uint256 expectedAssets = 1000000;
          
          uint256 assets = lenderCommitmentGroupSmartV2.previewMint(shares);
          assertEq(assets, expectedAssets, "previewMint should return correct assets at 1:1 rate");
          
          // Test with 2:1 exchange rate (1 share = 2 assets)
          lenderCommitmentGroupSmartV2.set_mockSharesExchangeRate(2 * 1e36);
          
          expectedAssets = 2000000; // 1000000 shares * 2 = 2000000 assets
          assets = lenderCommitmentGroupSmartV2.previewMint(shares);
          assertEq(assets, expectedAssets, "previewMint should return correct assets at 2:1 rate");
          
          // Test with 1:2 exchange rate (2 shares = 1 asset)
          lenderCommitmentGroupSmartV2.set_mockSharesExchangeRate(5e35); // 0.5 * 1e36
          

          uint256 newExchangeRate =   lenderCommitmentGroupSmartV2.sharesExchangeRate() ;
           assertEq(newExchangeRate, 5e35, "newExchangeRate should return correct ");
          


          expectedAssets = 500000; // 1000000 shares * 0.5 = 500000 assets
          assets = lenderCommitmentGroupSmartV2.previewMint(shares);
          assertEq(assets, expectedAssets, "previewMint should return correct assets at 1:2 rate");
          
          // Test initial deposit case (when totalSupply = 0)
          // Set up a new pool shares token to test initial deposit behavior
          lenderCommitmentGroupSmartV2.set_totalPrincipalTokensCommitted(0);
          lenderCommitmentGroupSmartV2.set_totalInterestCollected(0);
          
          // Mock totalSupply() of shares to be 0
         // vm.warp(1);
        //  vm.prank(address(lenderCommitmentGroupSmartV2));
         // newSharesToken.burn(address(lender), newSharesToken.balanceOf(address(lender)));
          
          // For initial deposit, previewMint should return 1:1 ratio regardless of exchange rate
         // assets = lenderCommitmentGroupSmartV2.previewMint(shares);
         // assertEq(assets, shares, "previewMint should return 1:1 for initial deposit");
      }
      
      // Test previewWithdraw function with different exchange rates
      function test_previewWithdraw() public {
          initialize_group_contract();
          
          // Fund the contract to make totalAssets() non-zero
          lenderCommitmentGroupSmartV2.set_totalPrincipalTokensCommitted(1000000);
          lenderCommitmentGroupSmartV2.set_totalInterestCollected(200000);
          
          // Test with 1:1 exchange rate
          lenderCommitmentGroupSmartV2.set_mockSharesExchangeRate(1e36);
          
          uint256 assets = 1000000;
          uint256 expectedShares = 1000000;
          
          uint256 shares = lenderCommitmentGroupSmartV2.previewWithdraw(assets);
          assertEq(shares, expectedShares, "previewWithdraw should return correct shares at 1:1 rate");
          
          // Test with 2:1 exchange rate (1 share = 2 assets)
          lenderCommitmentGroupSmartV2.set_mockSharesExchangeRate(2 * 1e36);
          
          expectedShares = 500000; // 1000000 assets / 2 = 500000 shares
          shares = lenderCommitmentGroupSmartV2.previewWithdraw(assets);
          assertEq(shares, expectedShares, "previewWithdraw should return correct shares at 2:1 rate");
          
          // Test with 1:2 exchange rate (2 shares = 1 asset)
          lenderCommitmentGroupSmartV2.set_mockSharesExchangeRate(5e35); // 0.5 * 1e36
          
          expectedShares = 2000000; // 1000000 assets * 2 = 2000000 shares
          shares = lenderCommitmentGroupSmartV2.previewWithdraw(assets);
          assertEq(shares, expectedShares, "previewWithdraw should return correct shares at 1:2 rate");
          
          // Test when totalAssets is zero
        /*  lenderCommitmentGroupSmartV2.set_totalPrincipalTokensCommitted(0);
          lenderCommitmentGroupSmartV2.set_totalInterestCollected(0);
          lenderCommitmentGroupSmartV2.set_tokenDifferenceFromLiquidations(0);
          lenderCommitmentGroupSmartV2.set_totalPrincipalTokensWithdrawn(0);
          
          shares = lenderCommitmentGroupSmartV2.previewWithdraw(assets);
          assertEq(shares, 0, "previewWithdraw should return 0 when totalAssets is 0"); */
      }
      
      // Test that preview functions align with the actual operations
      function test_preview_functions_match_actual_operations() public {
          initialize_group_contract();
          lenderCommitmentGroupSmartV2.set_mockSharesExchangeRate(1e36);
          
          // Test deposit preview matches actual deposit
          uint256 depositAmount = 1000000;
          uint256 expectedShares = lenderCommitmentGroupSmartV2.previewDeposit(depositAmount);
          
          vm.prank(address(lender));
          principalToken.approve(address(lenderCommitmentGroupSmartV2), depositAmount);
          
          vm.prank(address(lender));
          uint256 actualShares = lenderCommitmentGroupSmartV2.deposit(depositAmount, address(lender));
          
          assertEq(actualShares, expectedShares, "Actual deposit shares should match preview");
          
          // Test mint preview matches actual mint
          uint256 mintShares = 500000;
          uint256 expectedAssets = lenderCommitmentGroupSmartV2.previewMint(mintShares);
          
          vm.prank(address(lender));
          principalToken.approve(address(lenderCommitmentGroupSmartV2), expectedAssets);
          
          vm.prank(address(lender));
          uint256 actualAssets = lenderCommitmentGroupSmartV2.mint(mintShares, address(lender));
          
          assertEq(actualAssets, expectedAssets, "Actual mint assets should match preview");
          
          // Fund the contract for withdrawal tests
          principalToken.transfer(address(lenderCommitmentGroupSmartV2), 5e18);
          
          // Test withdraw preview matches actual withdraw
          uint256 withdrawAmount = 200000;
          uint256 expectedBurnShares = lenderCommitmentGroupSmartV2.previewWithdraw(withdrawAmount);
          
          vm.warp(1e6); // Advance time to satisfy withdraw delay
          
          vm.prank(address(lender));
          uint256 actualBurnShares = lenderCommitmentGroupSmartV2.withdraw(
              withdrawAmount,
              address(lender),
              address(lender)
          );
          
          assertEq(actualBurnShares, expectedBurnShares, "Actual withdraw shares burned should match preview");
          
          // Test redeem preview matches actual redeem
          uint256 redeemShares = 200000;
          uint256 expectedRedeemAssets = lenderCommitmentGroupSmartV2.previewRedeem(redeemShares);
          
          vm.warp(1e7); // Advance time to satisfy withdraw delay
          
          vm.prank(address(lender));
          uint256 actualRedeemAssets = lenderCommitmentGroupSmartV2.redeem(
              redeemShares,
              address(lender),
              address(lender)
          );
          
          assertEq(actualRedeemAssets, expectedRedeemAssets, "Actual redeem assets should match preview");
      }
            

}