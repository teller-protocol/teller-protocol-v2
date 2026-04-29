// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "../Testable.sol";

import { LenderCommitmentGroup_Pool_V3_Override } from "./LenderCommitmentGroup_Pool_V3_Override.sol";

import {TestERC20Token} from "../tokens/TestERC20Token.sol";

import {MarketRegistry} from "../../contracts/MarketRegistry.sol";
import {SmartCommitmentForwarder} from "../../contracts/LenderCommitmentForwarder/SmartCommitmentForwarder.sol";
import {TellerV2SolMock} from "../../contracts/mock/TellerV2SolMock.sol";
import {MockPriceAdapter} from "../../contracts/mock/MockPriceAdapter.sol";
import { PaymentType, PaymentCycleType } from "../../contracts/libraries/V2Calculations.sol";
import { LoanDetails, Payment, BidState , Bid, Terms } from "../../contracts/TellerV2Storage.sol";

import { ILenderCommitmentGroup_V3 } from "../../contracts/interfaces/ILenderCommitmentGroup_V3.sol";
import { IPriceAdapter } from "../../contracts/interfaces/IPriceAdapter.sol";

import {ILenderCommitmentGroupSharesIntegrated} from "../../contracts/interfaces/ILenderCommitmentGroupSharesIntegrated.sol";

import {ProtocolPausingManager} from "../../contracts/pausing/ProtocolPausingManager.sol";

import "lib/forge-std/src/console.sol";
import "lib/forge-std/src/Vm.sol";

// Helper contract to simulate a user
contract User {}

contract LenderCommitmentGroup_Pool_V3_Test is Testable {
    constructor() {}

    User private borrower;
    User private lender;
    User private liquidator;

    TestERC20Token principalToken;
    TestERC20Token collateralToken;

    LenderCommitmentGroup_Pool_V3_Override lenderCommitmentGroupV3;

    MarketRegistry _marketRegistry;
    TellerV2SolMock _tellerV2;
    SmartCommitmentForwarder _smartCommitmentForwarder;
    MockPriceAdapter _mockPriceAdapter;

    ProtocolPausingManager _protocolPausingManager;

    // Q96 = 2^96, used for price ratio
    uint256 constant Q96 = 0x1000000000000000000000000;

    function setUp() public {
        borrower = new User();
        lender = new User();
        liquidator = new User();

        _tellerV2 = new TellerV2SolMock();
        _marketRegistry = new MarketRegistry();
        _smartCommitmentForwarder = new SmartCommitmentForwarder(
            address(_tellerV2), address(_marketRegistry));

        _mockPriceAdapter = new MockPriceAdapter();
        // Set a reasonable default price: 1:1 in Q96 format
        _mockPriceAdapter.setMockPriceRatioQ96(Q96);

        _protocolPausingManager = new ProtocolPausingManager();
        _protocolPausingManager.initialize();

        _tellerV2.setProtocolPausingManager(address(_protocolPausingManager));

        principalToken = new TestERC20Token("wrappedETH", "WETH", 1e24, 18);
        collateralToken = new TestERC20Token("PEPE", "pepe", 1e24, 18);

        principalToken.transfer(address(lender), 1e18);
        collateralToken.transfer(address(borrower), 1e18);
        principalToken.transfer(address(liquidator), 1e18);

        lenderCommitmentGroupV3 = new LenderCommitmentGroup_Pool_V3_Override(
            address(_tellerV2),
            address(_smartCommitmentForwarder)
        );
    }

    function _buildPriceAdapterRoute() internal view returns (bytes memory) {
        // Encode a dummy route - the mock adapter doesn't care about content
        // but registerPriceRoute needs non-empty bytes
        bytes memory route = abi.encode(
            address(principalToken),
            address(collateralToken),
            uint32(5)
        );
        return route;
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

        ILenderCommitmentGroup_V3.CommitmentGroupConfig memory groupConfig = ILenderCommitmentGroup_V3.CommitmentGroupConfig({
            principalTokenAddress: _principalTokenAddress,
            collateralTokenAddress: _collateralTokenAddress,
            marketId: _marketId,
            maxLoanDuration: _maxLoanDuration,
            interestRateLowerBound: _interestRateLowerBound,
            interestRateUpperBound: _interestRateUpperBound,
            liquidityThresholdPercent: _liquidityThresholdPercent,
            collateralRatio: _collateralRatio
        });

        bytes memory route = _buildPriceAdapterRoute();

        lenderCommitmentGroupV3.initialize(
            groupConfig,
            address(_mockPriceAdapter),
            route
        );
    }

    // ============ Initialization Tests ============

    function test_initialize() public {
        address _principalTokenAddress = address(principalToken);
        address _collateralTokenAddress = address(collateralToken);
        uint256 _marketId = 1;
        uint32 _maxLoanDuration = 5000000;
        uint16 _interestRateLowerBound = 100;
        uint16 _interestRateUpperBound = 800;
        uint16 _liquidityThresholdPercent = 10000;
        uint16 _collateralRatio = 10000;

        ILenderCommitmentGroup_V3.CommitmentGroupConfig memory groupConfig = ILenderCommitmentGroup_V3.CommitmentGroupConfig({
            principalTokenAddress: _principalTokenAddress,
            collateralTokenAddress: _collateralTokenAddress,
            marketId: _marketId,
            maxLoanDuration: _maxLoanDuration,
            interestRateLowerBound: _interestRateLowerBound,
            interestRateUpperBound: _interestRateUpperBound,
            liquidityThresholdPercent: _liquidityThresholdPercent,
            collateralRatio: _collateralRatio
        });

        bytes memory route = _buildPriceAdapterRoute();

        lenderCommitmentGroupV3.initialize(
            groupConfig,
            address(_mockPriceAdapter),
            route
        );

        // Verify state was set
        assertEq(address(lenderCommitmentGroupV3.principalToken()), _principalTokenAddress);
        assertEq(address(lenderCommitmentGroupV3.collateralToken()), _collateralTokenAddress);
        assertEq(lenderCommitmentGroupV3.priceAdapter(), address(_mockPriceAdapter));
        assertTrue(lenderCommitmentGroupV3.priceRouteHash() != bytes32(0), "Price route hash should be set");
    }

    function test_initialize_reverts_invalid_interest_rates() public {
        ILenderCommitmentGroup_V3.CommitmentGroupConfig memory groupConfig = ILenderCommitmentGroup_V3.CommitmentGroupConfig({
            principalTokenAddress: address(principalToken),
            collateralTokenAddress: address(collateralToken),
            marketId: 1,
            maxLoanDuration: 5000000,
            interestRateLowerBound: 900,
            interestRateUpperBound: 800, // lower > upper
            liquidityThresholdPercent: 10000,
            collateralRatio: 10000
        });

        bytes memory route = _buildPriceAdapterRoute();

        vm.expectRevert(bytes("IRLB"));
        lenderCommitmentGroupV3.initialize(
            groupConfig,
            address(_mockPriceAdapter),
            route
        );
    }

    function test_initialize_reverts_invalid_liquidity_threshold() public {
        ILenderCommitmentGroup_V3.CommitmentGroupConfig memory groupConfig = ILenderCommitmentGroup_V3.CommitmentGroupConfig({
            principalTokenAddress: address(principalToken),
            collateralTokenAddress: address(collateralToken),
            marketId: 1,
            maxLoanDuration: 5000000,
            interestRateLowerBound: 100,
            interestRateUpperBound: 800,
            liquidityThresholdPercent: 10001, // > 10000
            collateralRatio: 10000
        });

        bytes memory route = _buildPriceAdapterRoute();

        vm.expectRevert(bytes("ILTP"));
        lenderCommitmentGroupV3.initialize(
            groupConfig,
            address(_mockPriceAdapter),
            route
        );
    }

    function test_initialize_cannot_reinitialize() public {
        initialize_group_contract();

        ILenderCommitmentGroup_V3.CommitmentGroupConfig memory groupConfig = ILenderCommitmentGroup_V3.CommitmentGroupConfig({
            principalTokenAddress: address(principalToken),
            collateralTokenAddress: address(collateralToken),
            marketId: 1,
            maxLoanDuration: 5000000,
            interestRateLowerBound: 100,
            interestRateUpperBound: 800,
            liquidityThresholdPercent: 10000,
            collateralRatio: 10000
        });

        bytes memory route = _buildPriceAdapterRoute();

        vm.expectRevert();
        lenderCommitmentGroupV3.initialize(
            groupConfig,
            address(_mockPriceAdapter),
            route
        );
    }

    // ============ ERC4626 Deposit Tests ============

    function test_erc4626_deposit_first_deposit_only_owner() public {
        initialize_group_contract();
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(1e36);

        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupV3), 1000000);

        // Non-owner should fail with "FDM" (First Deposit Made check)
        vm.prank(address(lender));
        vm.expectRevert();
        lenderCommitmentGroupV3.deposit(1000000, address(lender));
    }

    function test_erc4626_deposit() public {
        initialize_group_contract();
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(1e36);
        lenderCommitmentGroupV3.force_set_firstDepositMade(true);

        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupV3), 1000000);

        vm.prank(address(lender));
        uint256 sharesAmount = lenderCommitmentGroupV3.deposit(1000000, address(lender));

        uint256 expectedSharesAmount = 1000000;
        assertEq(
            sharesAmount,
            expectedSharesAmount,
            "Received an unexpected amount of shares"
        );
    }

    function test_erc4626_deposit_first_deposit_by_owner() public {
        initialize_group_contract();
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(1e36);

        // The test contract is the owner after initialize
        principalToken.approve(address(lenderCommitmentGroupV3), 2e6);

        // Owner can make the first deposit, must be >= 1e6 shares
        uint256 sharesAmount = lenderCommitmentGroupV3.deposit(2e6, address(this));
        assertGe(sharesAmount, 1e6, "First deposit shares should be >= 1e6");
        assertTrue(lenderCommitmentGroupV3.firstDepositMade(), "firstDepositMade should be true");
    }

    function test_erc4626_deposit_first_deposit_too_small() public {
        initialize_group_contract();
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(1e36);

        // Owner tries first deposit but too small (< 1e6 shares)
        principalToken.approve(address(lenderCommitmentGroupV3), 100);

        vm.expectRevert(bytes("IS"));
        lenderCommitmentGroupV3.deposit(100, address(this));
    }

    // ============ ERC4626 Mint Tests ============

    function test_erc4626_mint() public {
        initialize_group_contract();
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(1e36);
        lenderCommitmentGroupV3.force_set_firstDepositMade(true);

        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupV3), 1000000);

        vm.prank(address(lender));
        uint256 assetsAmount = lenderCommitmentGroupV3.mint(1000000, address(lender));

        uint256 expectedAssetsAmount = 1000000;
        assertEq(
            assetsAmount,
            expectedAssetsAmount,
            "Used an unexpected amount of assets"
        );
    }

    // ============ ERC4626 Redeem Tests ============

    function test_erc4626_redeem() public {
        principalToken.transfer(address(lenderCommitmentGroupV3), 1e18);

        initialize_group_contract();
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(1e36);

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);

        vm.warp(1e6);

        // Mint shares to lender
        uint256 sharesAmount = 1000000;
        vm.prank(address(lenderCommitmentGroupV3));
        lenderCommitmentGroupV3.force_mint_shares(address(lender), sharesAmount);

        vm.warp(1e7);

        vm.prank(address(lender));
        uint256 assetsReceived = lenderCommitmentGroupV3.redeem(
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

    // ============ ERC4626 Withdraw Tests ============

    function test_erc4626_withdraw() public {
        principalToken.transfer(address(lenderCommitmentGroupV3), 1e18);

        initialize_group_contract();
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(1e36);

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);

        vm.warp(1e6);

        // Mint shares to lender
        uint256 sharesAmount = 1000000;
        vm.prank(address(lenderCommitmentGroupV3));
        lenderCommitmentGroupV3.force_mint_shares(address(lender), sharesAmount);

        vm.warp(1e7);

        vm.prank(address(lender));
        uint256 sharesRedeemedAmount = lenderCommitmentGroupV3.withdraw(
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

    function test_erc4626_withdraw_fails_without_warp() public {
        principalToken.transfer(address(lenderCommitmentGroupV3), 1e18);

        initialize_group_contract();
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(1e36);

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);

        vm.warp(1e6);

        // Mint shares to lender
        uint256 sharesAmount = 1000000;
        vm.prank(address(lenderCommitmentGroupV3));
        lenderCommitmentGroupV3.force_mint_shares(address(lender), sharesAmount);

        // Don't warp — shares were just transferred

        uint256 sharesLastTransferredAt = ILenderCommitmentGroupSharesIntegrated(address(lenderCommitmentGroupV3)).getSharesLastTransferredAt(address(lender));
        assertEq(sharesLastTransferredAt, 1e6, "unexpected sharesLastTransferredAt");

        lenderCommitmentGroupV3.force_set_withdraw_delay(9000);

        vm.expectRevert();
        vm.prank(address(lender));
        lenderCommitmentGroupV3.withdraw(
            1000000,
            address(lender),
            address(lender)
        );
    }

    function test_erc4626_withdraw_unauthorized() public {
        principalToken.transfer(address(lenderCommitmentGroupV3), 1e18);

        initialize_group_contract();
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(1e36);
        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);

        vm.warp(1e6);

        uint256 sharesAmount = 1000000;
        vm.prank(address(lenderCommitmentGroupV3));
        lenderCommitmentGroupV3.force_mint_shares(address(lender), sharesAmount);

        vm.warp(1e7);

        // Borrower tries to withdraw lender's shares
        vm.expectRevert(bytes("UA"));
        vm.prank(address(borrower));
        lenderCommitmentGroupV3.withdraw(
            1000000,
            address(borrower),
            address(lender)
        );
    }

    function test_erc4626_redeem_unauthorized() public {
        principalToken.transfer(address(lenderCommitmentGroupV3), 1e18);

        initialize_group_contract();
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(1e36);
        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);

        vm.warp(1e6);

        uint256 sharesAmount = 1000000;
        vm.prank(address(lenderCommitmentGroupV3));
        lenderCommitmentGroupV3.force_mint_shares(address(lender), sharesAmount);

        vm.warp(1e7);

        // Borrower tries to redeem lender's shares
        vm.expectRevert(bytes("UA"));
        vm.prank(address(borrower));
        lenderCommitmentGroupV3.redeem(
            sharesAmount,
            address(borrower),
            address(lender)
        );
    }

    // ============ ERC4626 Accounting Tests ============

    function test_erc4626_accounting() public {
        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupV3.set_totalInterestCollected(500000);

        // Test totalAssets()
        uint256 totalAssets = lenderCommitmentGroupV3.totalAssets();
        assertEq(totalAssets, 1500000, "Incorrect total assets calculation");

        // Test convertToShares/convertToAssets with 1:1 exchange rate
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(1e36);

        uint256 shares = lenderCommitmentGroupV3.convertToShares(1000);
        assertEq(shares, 1000, "Incorrect shares conversion");

        uint256 assets = lenderCommitmentGroupV3.convertToAssets(1000);
        assertEq(assets, 1000, "Incorrect assets conversion");

        // Test with 2:1 exchange rate (1 share = 2 assets)
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(2 * 1e36);

        shares = lenderCommitmentGroupV3.convertToShares(1000);
        assertEq(shares, 500, "Incorrect shares conversion with 2:1 rate");

        assets = lenderCommitmentGroupV3.convertToAssets(500);
        assertEq(assets, 1000, "Incorrect assets conversion with 2:1 rate");
    }

    function test_totalAssets_with_withdrawals() public {
        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupV3.set_totalInterestCollected(200000);
        lenderCommitmentGroupV3.set_totalPrincipalTokensWithdrawn(300000);

        uint256 totalAssets = lenderCommitmentGroupV3.totalAssets();
        // 1000000 + 200000 - 300000 = 900000
        assertEq(totalAssets, 900000, "totalAssets should account for withdrawals");
    }

    function test_totalAssets_with_liquidation_losses() public {
        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupV3.set_tokenDifferenceFromLiquidations(-500000);

        uint256 totalAssets = lenderCommitmentGroupV3.totalAssets();
        // 1000000 - 500000 = 500000
        assertEq(totalAssets, 500000, "totalAssets should account for liquidation losses");
    }

    function test_totalAssets_floors_at_zero() public {
        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(100000);
        lenderCommitmentGroupV3.set_tokenDifferenceFromLiquidations(-500000);

        uint256 totalAssets = lenderCommitmentGroupV3.totalAssets();
        // Would be negative, floored to 0
        assertEq(totalAssets, 0, "totalAssets should floor at zero");
    }

    // ============ Lending (acceptFundsForAcceptBid) Tests ============

    function test_acceptFundsForAcceptBid() public {
        lenderCommitmentGroupV3.set_mock_requiredCollateralAmount(100);

        principalToken.transfer(address(lenderCommitmentGroupV3), 1e18);
        collateralToken.transfer(address(lenderCommitmentGroupV3), 1e18);

        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);

        uint256 principalAmount = 50;
        uint256 collateralAmount = 100;

        address collateralTokenAddress = address(lenderCommitmentGroupV3.collateralToken());
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
        lenderCommitmentGroupV3.acceptFundsForAcceptBid(
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
        lenderCommitmentGroupV3.set_mock_requiredCollateralAmount(100);

        principalToken.transfer(address(lenderCommitmentGroupV3), 1e18);
        collateralToken.transfer(address(lenderCommitmentGroupV3), 1e18);

        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);

        uint256 principalAmount = 100;
        uint256 collateralAmount = 0; // insufficient

        address collateralTokenAddress = address(lenderCommitmentGroupV3.collateralToken());
        uint256 collateralTokenId = 0;

        uint32 loanDuration = 5000000;
        uint16 interestRate = 100;

        uint256 bidId = 0;

        vm.expectRevert(bytes("C"));
        vm.prank(address(_smartCommitmentForwarder));
        lenderCommitmentGroupV3.acceptFundsForAcceptBid(
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

    function test_acceptFundsForAcceptBid_wrongCollateralToken() public {
        lenderCommitmentGroupV3.set_mock_requiredCollateralAmount(100);

        principalToken.transfer(address(lenderCommitmentGroupV3), 1e18);

        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);

        vm.expectRevert(bytes("MMCT"));
        vm.prank(address(_smartCommitmentForwarder));
        lenderCommitmentGroupV3.acceptFundsForAcceptBid(
            address(borrower),
            0,
            100,
            100,
            address(principalToken), // wrong token
            0,
            5000000,
            100
        );
    }

    function test_acceptFundsForAcceptBid_loanDurationTooLong() public {
        lenderCommitmentGroupV3.set_mock_requiredCollateralAmount(100);

        principalToken.transfer(address(lenderCommitmentGroupV3), 1e18);

        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);

        address collateralTokenAddress = address(lenderCommitmentGroupV3.collateralToken());

        vm.expectRevert(bytes("LMD"));
        vm.prank(address(_smartCommitmentForwarder));
        lenderCommitmentGroupV3.acceptFundsForAcceptBid(
            address(borrower),
            0,
            100,
            200,
            collateralTokenAddress,
            0,
            5000001, // exceeds maxLoanDuration
            100
        );
    }

    function test_acceptFundsForAcceptBid_onlySmartCommitmentForwarder() public {
        lenderCommitmentGroupV3.set_mock_requiredCollateralAmount(100);

        principalToken.transfer(address(lenderCommitmentGroupV3), 1e18);

        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);

        address collateralTokenAddress = address(lenderCommitmentGroupV3.collateralToken());

        vm.expectRevert(bytes("OSCF"));
        // Not called from SCF
        lenderCommitmentGroupV3.acceptFundsForAcceptBid(
            address(borrower),
            0,
            100,
            200,
            collateralTokenAddress,
            0,
            5000000,
            100
        );
    }

    // ============ Repayment Callback Tests ============

    function test_repayLoanCallback() public {
        uint256 principalAmount = 100;
        uint256 interestAmount = 50;
        address repayer = address(borrower);

        uint256 bidId = 0;

        lenderCommitmentGroupV3.mock_setBidActive(bidId);
        lenderCommitmentGroupV3.set_mockActiveBidsAmountDueRemaining(bidId, principalAmount);

        vm.prank(address(_tellerV2));
        lenderCommitmentGroupV3.repayLoanCallback(
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
        lenderCommitmentGroupV3.repayLoanCallback(
            bidId,
            address(repayer),
            principalAmount,
            interestAmount
        );
    }

    function test_repayLoanCallback_onlyTellerV2() public {
        uint256 bidId = 0;
        lenderCommitmentGroupV3.mock_setBidActive(bidId);
        lenderCommitmentGroupV3.set_mockActiveBidsAmountDueRemaining(bidId, 100);

        vm.expectRevert(bytes("OTV2"));
        lenderCommitmentGroupV3.repayLoanCallback(
            bidId,
            address(borrower),
            100,
            50
        );
    }

    // ============ Liquidation Tests ============

    function test_liquidation_bid_not_active() public {
        initialize_group_contract();

        vm.warp(1e10);

        uint256 marketId = 0;
        uint256 principalAmount = 100;
        uint32 loanDuration = 500000;
        uint16 interestRate = 50;

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
        lenderCommitmentGroupV3.liquidateDefaultedLoanWithIncentive(
            bidId,
            tokenAmountDifference
        );
    }

    function test_liquidation_handles_partially_repaid_loan() public {
        initialize_group_contract();

        vm.warp(10000000000);

        uint256 marketId = 0;
        uint256 principalAmount = 900;
        uint32 loanDuration = 500000;
        uint16 interestRate = 50;

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

        lenderCommitmentGroupV3.set_mockBidAsActiveForGroup(bidId, true);
        lenderCommitmentGroupV3.set_mockActiveBidsAmountDueRemaining(bidId, principalAmount);

        uint256 principalTokensCommitted = 4000;
        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(principalTokensCommitted);

        _tellerV2.mock_setLoanDefaultTimestamp(block.timestamp - 1000);

        lenderCommitmentGroupV3.mock_setMinimumAmountDifferenceToCloseDefaultedLoan(500);

        vm.prank(address(liquidator));
        principalToken.approve(address(lenderCommitmentGroupV3), principalAmount + 500);

        vm.prank(address(liquidator));
        lenderCommitmentGroupV3.liquidateDefaultedLoanWithIncentive(
            bidId,
            500
        );
    }

    // ============ Liquidation Auction Math Tests ============

    function test_getMinimumAmountDifferenceToCloseDefaultedLoan() public {
        initialize_group_contract();

        uint256 amountDue = 500;

        vm.warp(10000);
        uint256 loanDefaultTimestamp = block.timestamp - 2000;

        int256 min_amount = lenderCommitmentGroupV3.super_getMinimumAmountDifferenceToCloseDefaultedLoan(
            amountDue,
            loanDefaultTimestamp
        );

        int256 expectedMinAmount = 3720; // (86400 - 10000 - 2000) / 10000 * 500
        assertEq(min_amount, expectedMinAmount, "min_amount unexpected");
    }

    function test_getMinimumAmountDifferenceToCloseDefaultedLoan_zero_time() public {
        initialize_group_contract();

        uint256 amountDue = 500;

        vm.warp(10000);
        uint256 loanDefaultTimestamp = block.timestamp;

        vm.expectRevert(bytes("LDT"));
        lenderCommitmentGroupV3.super_getMinimumAmountDifferenceToCloseDefaultedLoan(
            amountDue,
            loanDefaultTimestamp
        );
    }

    function test_getMinimumAmountDifferenceToCloseDefaultedLoan_full_time() public {
        initialize_group_contract();

        uint256 amountDue = 500;

        vm.warp(100000);
        uint256 loanDefaultTimestamp = block.timestamp - 22000;

        int256 min_amount = lenderCommitmentGroupV3.super_getMinimumAmountDifferenceToCloseDefaultedLoan(
            amountDue,
            loanDefaultTimestamp
        );

        int256 expectedMinAmount = 2720;
        assertEq(min_amount, expectedMinAmount, "min_amount unexpected");
    }

    function test_getMinimumAmountDifferenceToCloseDefaultedLoan_fully_expired() public {
        initialize_group_contract();

        uint256 amountDue = 500;

        vm.warp(200000);
        // Over 96400 seconds since default => capped at -10000
        uint256 loanDefaultTimestamp = block.timestamp - 100000;

        int256 min_amount = lenderCommitmentGroupV3.super_getMinimumAmountDifferenceToCloseDefaultedLoan(
            amountDue,
            loanDefaultTimestamp
        );

        // incentiveMultiplier capped at -10000, so: 500 * -10000 / 10000 = -500
        int256 expectedMinAmount = -500;
        assertEq(min_amount, expectedMinAmount, "min_amount should be capped at -amountDue");
    }

    // ============ Exchange Rate Tests ============

    function test_get_shares_exchange_rate_scenario_A() public {
        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalInterestCollected(0);
        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(5000000);

        uint256 rate = lenderCommitmentGroupV3.super_sharesExchangeRate();
        assertEq(rate, 1e36, "unexpected sharesExchangeRate");
    }

    function test_get_shares_exchange_rate_scenario_B() public {
        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalInterestCollected(1000000);
        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupV3.set_totalPrincipalTokensWithdrawn(1000000);

        uint256 rate = lenderCommitmentGroupV3.super_sharesExchangeRate();
        assertEq(rate, 1e36, "unexpected sharesExchangeRate");
    }

    function test_get_shares_exchange_rate_scenario_C() public {
        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupV3.set_totalInterestCollected(1000000);

        uint256 sharesAmount = 500000;

        vm.prank(address(lenderCommitmentGroupV3));
        lenderCommitmentGroupV3.force_mint_shares(address(lender), sharesAmount);

        uint256 poolTotalEstimatedValue = lenderCommitmentGroupV3.public_getPoolTotalEstimatedValue();
        assertEq(poolTotalEstimatedValue, 2 * 1000000, "unexpected poolTotalEstimatedValue");

        uint256 rate = lenderCommitmentGroupV3.super_sharesExchangeRate();
        assertEq(rate, 4 * 1e36, "unexpected sharesExchangeRate");
    }

    function test_get_shares_exchange_rate_after_default_liquidation_A() public {
        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupV3.set_totalInterestCollected(1000000);
        lenderCommitmentGroupV3.set_tokenDifferenceFromLiquidations(-1000000);

        uint256 sharesAmount = 1000000;

        vm.prank(address(lenderCommitmentGroupV3));
        lenderCommitmentGroupV3.force_mint_shares(address(lender), sharesAmount);

        uint256 poolTotalEstimatedValue = lenderCommitmentGroupV3.public_getPoolTotalEstimatedValue();
        assertEq(poolTotalEstimatedValue, 1 * 1000000, "unexpected poolTotalEstimatedValue");

        uint256 rate = lenderCommitmentGroupV3.super_sharesExchangeRate();
        assertEq(rate, 1 * 1e36, "unexpected sharesExchangeRate");
    }

    function test_get_shares_exchange_rate_after_default_liquidation_B() public {
        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupV3.set_tokenDifferenceFromLiquidations(-500000);

        uint256 sharesAmount = 1000000;

        vm.prank(address(lenderCommitmentGroupV3));
        lenderCommitmentGroupV3.force_mint_shares(address(lender), sharesAmount);

        uint256 poolTotalEstimatedValue = lenderCommitmentGroupV3.public_getPoolTotalEstimatedValue();
        assertEq(poolTotalEstimatedValue, 1 * 500000, "unexpected poolTotalEstimatedValue");

        uint256 rate = lenderCommitmentGroupV3.super_sharesExchangeRate();
        assertEq(rate, 1e36 / 2, "unexpected sharesExchangeRate");
    }

    function test_sharesExchangeRate_initial_is_1to1() public {
        initialize_group_contract();

        // No shares minted, no deposits — should return EXCHANGE_RATE_EXPANSION_FACTOR (1e36)
        uint256 rate = lenderCommitmentGroupV3.super_sharesExchangeRate();
        assertEq(rate, 1e36, "Initial exchange rate should be 1:1");
    }

    // ============ Pausing Tests ============

    function test_pause_unpause() public {
        initialize_group_contract();

        address pausingManager = _tellerV2.getProtocolPausingManager();

        vm.prank(address(this));
        _protocolPausingManager.addPauser(address(_tellerV2));

        vm.prank(address(_tellerV2));
        lenderCommitmentGroupV3.pausePool();
        assertTrue(lenderCommitmentGroupV3.paused(), "Contract should be paused");

        vm.prank(address(_tellerV2));
        lenderCommitmentGroupV3.unpausePool();
        assertFalse(lenderCommitmentGroupV3.paused(), "Contract should be unpaused");

        uint256 lastUnpausedAt = lenderCommitmentGroupV3.getLastUnpausedAt();
        assertEq(lastUnpausedAt, block.timestamp, "lastUnpausedAt not set correctly");
    }

    function test_pause_borrowing() public {
        initialize_group_contract();

        _protocolPausingManager.addPauser(address(_tellerV2));

        vm.prank(address(_tellerV2));
        lenderCommitmentGroupV3.pauseBorrowing();
        assertTrue(lenderCommitmentGroupV3.borrowingPaused(), "Borrowing should be paused");

        vm.prank(address(_tellerV2));
        lenderCommitmentGroupV3.unpauseBorrowing();
        assertFalse(lenderCommitmentGroupV3.borrowingPaused(), "Borrowing should be unpaused");
    }

    function test_pause_liquidation_auction() public {
        initialize_group_contract();

        _protocolPausingManager.addPauser(address(_tellerV2));

        vm.prank(address(_tellerV2));
        lenderCommitmentGroupV3.pauseLiquidationAuction();
        assertTrue(lenderCommitmentGroupV3.liquidationAuctionPaused(), "Liquidation auction should be paused");

        vm.prank(address(_tellerV2));
        lenderCommitmentGroupV3.unpauseLiquidationAuction();
        assertFalse(lenderCommitmentGroupV3.liquidationAuctionPaused(), "Liquidation auction should be unpaused");
    }

    function test_deposit_blocked_when_paused() public {
        initialize_group_contract();
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(1e36);
        lenderCommitmentGroupV3.force_set_firstDepositMade(true);

        _protocolPausingManager.addPauser(address(_tellerV2));

        vm.prank(address(_tellerV2));
        lenderCommitmentGroupV3.pausePool();

        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupV3), 1000000);

        vm.expectRevert(bytes("P"));
        vm.prank(address(lender));
        lenderCommitmentGroupV3.deposit(1000000, address(lender));
    }

    // ============ Preview Functions Tests ============

    function test_previewDeposit() public {
        initialize_group_contract();

        // Test with 1:1 exchange rate
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(1e36);

        uint256 assets = 1000000;
        uint256 expectedShares = 1000000;

        uint256 shares = lenderCommitmentGroupV3.previewDeposit(assets);
        assertEq(shares, expectedShares, "previewDeposit should return correct shares at 1:1 rate");

        // Test with 2:1 exchange rate (1 share = 2 assets)
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(2 * 1e36);

        expectedShares = 500000;
        shares = lenderCommitmentGroupV3.previewDeposit(assets);
        assertEq(shares, expectedShares, "previewDeposit should return correct shares at 2:1 rate");

        // Test with 1:2 exchange rate (2 shares = 1 asset)
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(5e35); // 0.5 * 1e36

        expectedShares = 2000000;
        shares = lenderCommitmentGroupV3.previewDeposit(assets);
        assertEq(shares, expectedShares, "previewDeposit should return correct shares at 1:2 rate");
    }

    function test_previewMint() public {
        initialize_group_contract();

        // Test with 1:1 exchange rate
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(1e36);

        uint256 shares = 1000000;
        uint256 expectedAssets = 1000000;

        uint256 assets = lenderCommitmentGroupV3.previewMint(shares);
        assertEq(assets, expectedAssets, "previewMint should return correct assets at 1:1 rate");

        // Test with 2:1 exchange rate (1 share = 2 assets)
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(2 * 1e36);

        expectedAssets = 2000000;
        assets = lenderCommitmentGroupV3.previewMint(shares);
        assertEq(assets, expectedAssets, "previewMint should return correct assets at 2:1 rate");

        // Test with 1:2 exchange rate
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(5e35);

        expectedAssets = 500000;
        assets = lenderCommitmentGroupV3.previewMint(shares);
        assertEq(assets, expectedAssets, "previewMint should return correct assets at 1:2 rate");
    }

    function test_previewWithdraw() public {
        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupV3.set_totalInterestCollected(200000);

        // Test with 1:1 exchange rate
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(1e36);

        uint256 assets = 1000000;
        uint256 expectedShares = 1000000;

        uint256 shares = lenderCommitmentGroupV3.previewWithdraw(assets);
        assertEq(shares, expectedShares, "previewWithdraw should return correct shares at 1:1 rate");

        // Test with 2:1 exchange rate
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(2 * 1e36);

        expectedShares = 500000;
        shares = lenderCommitmentGroupV3.previewWithdraw(assets);
        assertEq(shares, expectedShares, "previewWithdraw should return correct shares at 2:1 rate");

        // Test with 1:2 exchange rate
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(5e35);

        expectedShares = 2000000;
        shares = lenderCommitmentGroupV3.previewWithdraw(assets);
        assertEq(shares, expectedShares, "previewWithdraw should return correct shares at 1:2 rate");
    }

    function test_previewRedeem() public {
        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);

        // Test with 1:1 exchange rate
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(1e36);

        uint256 shares = 1000000;
        uint256 expectedAssets = 1000000;

        uint256 assets = lenderCommitmentGroupV3.previewRedeem(shares);
        assertEq(assets, expectedAssets, "previewRedeem should return correct assets at 1:1 rate");

        // Test with 2:1 exchange rate
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(2 * 1e36);

        // 1 share = 2 assets, so 1000000 shares = 2000000 assets
        expectedAssets = 2000000;
        assets = lenderCommitmentGroupV3.previewRedeem(shares);
        assertEq(assets, expectedAssets, "previewRedeem should return correct assets at 2:1 rate");
    }

    // ============ Preview Functions Match Actual Operations ============

    function test_preview_functions_match_actual_operations() public {
        initialize_group_contract();
        lenderCommitmentGroupV3.set_mockSharesExchangeRate(1e36);
        lenderCommitmentGroupV3.force_set_firstDepositMade(true);

        // Test deposit preview matches actual deposit
        uint256 depositAmount = 1000000;
        uint256 expectedShares = lenderCommitmentGroupV3.previewDeposit(depositAmount);

        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupV3), depositAmount);

        vm.prank(address(lender));
        uint256 actualShares = lenderCommitmentGroupV3.deposit(depositAmount, address(lender));

        assertEq(actualShares, expectedShares, "Actual deposit shares should match preview");

        // Test mint preview matches actual mint
        uint256 mintShares = 500000;
        uint256 expectedAssets = lenderCommitmentGroupV3.previewMint(mintShares);

        vm.prank(address(lender));
        principalToken.approve(address(lenderCommitmentGroupV3), expectedAssets);

        vm.prank(address(lender));
        uint256 actualAssets = lenderCommitmentGroupV3.mint(mintShares, address(lender));

        assertEq(actualAssets, expectedAssets, "Actual mint assets should match preview");

        // Fund the contract for withdrawal tests
        principalToken.transfer(address(lenderCommitmentGroupV3), 5e18);

        // Test withdraw preview matches actual withdraw
        uint256 withdrawAmount = 200000;
        uint256 expectedBurnShares = lenderCommitmentGroupV3.previewWithdraw(withdrawAmount);

        vm.warp(1e6); // Advance time to satisfy withdraw delay

        vm.prank(address(lender));
        uint256 actualBurnShares = lenderCommitmentGroupV3.withdraw(
            withdrawAmount,
            address(lender),
            address(lender)
        );

        assertEq(actualBurnShares, expectedBurnShares, "Actual withdraw shares burned should match preview");

        // Test redeem preview matches actual redeem
        uint256 redeemShares = 200000;
        uint256 expectedRedeemAssets = lenderCommitmentGroupV3.previewRedeem(redeemShares);

        vm.warp(1e7); // Advance time to satisfy withdraw delay

        vm.prank(address(lender));
        uint256 actualRedeemAssets = lenderCommitmentGroupV3.redeem(
            redeemShares,
            address(lender),
            address(lender)
        );

        assertEq(actualRedeemAssets, expectedRedeemAssets, "Actual redeem assets should match preview");
    }

    // ============ Pool Utilization & Interest Rate Tests ============

    function test_getPoolUtilizationRatio() public {
        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupV3.set_totalPrincipalTokensLended(500000);

        // 500000 / 1000000 = 50% = 5000
        uint16 ratio = lenderCommitmentGroupV3.getPoolUtilizationRatio(0);
        assertEq(ratio, 5000, "Utilization ratio should be 50%");
    }

    function test_getPoolUtilizationRatio_with_delta() public {
        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupV3.set_totalPrincipalTokensLended(500000);

        // (500000 + 250000) / 1000000 = 75% = 7500
        uint16 ratio = lenderCommitmentGroupV3.getPoolUtilizationRatio(250000);
        assertEq(ratio, 7500, "Utilization ratio should be 75%");
    }

    function test_getPoolUtilizationRatio_capped_at_100() public {
        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupV3.set_totalPrincipalTokensLended(1500000);

        uint16 ratio = lenderCommitmentGroupV3.getPoolUtilizationRatio(0);
        assertEq(ratio, 10000, "Utilization ratio should be capped at 100%");
    }

    function test_getMinInterestRate() public {
        initialize_group_contract();

        // At 0% utilization, min rate = lowerBound (0)
        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);
        uint16 rate = lenderCommitmentGroupV3.getMinInterestRate(0);
        assertEq(rate, 0, "Min rate at 0% util should be lowerBound");
    }

    // ============ Principal Available to Borrow Tests ============

    function test_getPrincipalAmountAvailableToBorrow() public {
        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);

        uint256 available = lenderCommitmentGroupV3.getPrincipalAmountAvailableToBorrow();
        // liquidityThresholdPercent = 10000 (100%), so all committed is available
        assertEq(available, 1000000, "All committed principal should be available");
    }

    function test_getPrincipalAmountAvailableToBorrow_with_loans() public {
        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupV3.set_totalPrincipalTokensLended(600000);

        uint256 available = lenderCommitmentGroupV3.getPrincipalAmountAvailableToBorrow();
        assertEq(available, 400000, "Available should be committed minus lended");
    }

    function test_getPrincipalAmountAvailableToBorrow_threshold_reached() public {
        initialize_group_contract();

        lenderCommitmentGroupV3.set_totalPrincipalTokensCommitted(1000000);
        lenderCommitmentGroupV3.set_totalPrincipalTokensLended(1000000);

        uint256 available = lenderCommitmentGroupV3.getPrincipalAmountAvailableToBorrow();
        assertEq(available, 0, "Nothing should be available when fully utilized");
    }

    // ============ Price Adapter Integration Tests ============

    function test_calculateCollateralTokensAmountEquivalentToPrincipalTokens() public {
        initialize_group_contract();
        lenderCommitmentGroupV3.set_useRealGetRequiredCollateral(true);

        // With Q96 price (1:1), 1000 principal should need 1000 collateral
        _mockPriceAdapter.setMockPriceRatioQ96(Q96);

        uint256 collateralNeeded = lenderCommitmentGroupV3.calculateCollateralTokensAmountEquivalentToPrincipalTokens(1000);
        assertEq(collateralNeeded, 1000, "1:1 price should require equal collateral");
    }

    function test_calculateCollateralRequiredToBorrowPrincipal() public {
        initialize_group_contract();
        lenderCommitmentGroupV3.set_useRealGetRequiredCollateral(true);

        // collateralRatio = 10000 (100%), price is 1:1
        _mockPriceAdapter.setMockPriceRatioQ96(Q96);

        uint256 required = lenderCommitmentGroupV3.calculateCollateralRequiredToBorrowPrincipal(1000);
        // With 100% collateral ratio, required = baseAmount * 100% = 1000
        assertEq(required, 1000, "With 100% ratio and 1:1 price, should need equal collateral");
    }

    function test_calculateCollateralTokensAmount_with_different_price() public {
        initialize_group_contract();
        lenderCommitmentGroupV3.set_useRealGetRequiredCollateral(true);

        // Set price to 2:1 (1 collateral = 2 principal), so Q96 * 2
        _mockPriceAdapter.setMockPriceRatioQ96(Q96 * 2);

        uint256 collateralNeeded = lenderCommitmentGroupV3.calculateCollateralTokensAmountEquivalentToPrincipalTokens(1000);
        // With 2:1 price, 1000 principal needs 500 collateral
        assertEq(collateralNeeded, 500, "2:1 price should require half collateral");
    }

    // ============ setMaxPrincipalPerCollateralAmount Tests ============

    function test_setMaxPrincipalPerCollateralAmount_onlyOwner() public {
        initialize_group_contract();

        // Non-owner should revert
        vm.prank(address(borrower));
        vm.expectRevert("Ownable: caller is not the owner");
        lenderCommitmentGroupV3.setMaxPrincipalPerCollateralAmount(Q96);

        // Owner should succeed
        lenderCommitmentGroupV3.setMaxPrincipalPerCollateralAmount(Q96);
        assertEq(lenderCommitmentGroupV3.maxPrincipalPerCollateralAmount(), Q96);
    }

    function test_setMaxPrincipalPerCollateralAmount_zero_uses_oracle_only() public {
        initialize_group_contract();
        lenderCommitmentGroupV3.set_useRealGetRequiredCollateral(true);

        // Oracle price 2:1 (1 collateral = 2 principal)
        _mockPriceAdapter.setMockPriceRatioQ96(Q96 * 2);

        // maxPrincipalPerCollateralAmount = 0 (default), should use oracle price
        uint256 collateralNeeded = lenderCommitmentGroupV3.calculateCollateralTokensAmountEquivalentToPrincipalTokens(1000);
        assertEq(collateralNeeded, 500, "With cap=0, should use oracle price only");
    }

    function test_setMaxPrincipalPerCollateralAmount_caps_oracle_price() public {
        initialize_group_contract();
        lenderCommitmentGroupV3.set_useRealGetRequiredCollateral(true);

        // Oracle says 1 collateral = 4 principal (Q96 * 4)
        _mockPriceAdapter.setMockPriceRatioQ96(Q96 * 4);

        // Without cap: 1000 principal needs 250 collateral
        uint256 withoutCap = lenderCommitmentGroupV3.calculateCollateralTokensAmountEquivalentToPrincipalTokens(1000);
        assertEq(withoutCap, 250, "Without cap: 4:1 price means 250 collateral");

        // Set cap to 2:1 (Q96 * 2) — lower than oracle's 4:1
        // min(4*Q96, 2*Q96) = 2*Q96, so borrower needs MORE collateral
        lenderCommitmentGroupV3.setMaxPrincipalPerCollateralAmount(Q96 * 2);

        uint256 withCap = lenderCommitmentGroupV3.calculateCollateralTokensAmountEquivalentToPrincipalTokens(1000);
        assertEq(withCap, 500, "Cap at 2:1 should require 500 collateral");
    }

    function test_setMaxPrincipalPerCollateralAmount_ignored_when_oracle_lower() public {
        initialize_group_contract();
        lenderCommitmentGroupV3.set_useRealGetRequiredCollateral(true);

        // Oracle says 1 collateral = 2 principal (Q96 * 2)
        _mockPriceAdapter.setMockPriceRatioQ96(Q96 * 2);

        // Set cap to 4:1 (Q96 * 4) — higher than oracle's 2:1
        // min(2*Q96, 4*Q96) = 2*Q96, so cap has no effect
        lenderCommitmentGroupV3.setMaxPrincipalPerCollateralAmount(Q96 * 4);

        uint256 collateralNeeded = lenderCommitmentGroupV3.calculateCollateralTokensAmountEquivalentToPrincipalTokens(1000);
        assertEq(collateralNeeded, 500, "Cap higher than oracle should have no effect");
    }

    function test_setMaxPrincipalPerCollateralAmount_can_be_reset_to_zero() public {
        initialize_group_contract();
        lenderCommitmentGroupV3.set_useRealGetRequiredCollateral(true);

        _mockPriceAdapter.setMockPriceRatioQ96(Q96 * 4);

        // Set cap, then clear it
        lenderCommitmentGroupV3.setMaxPrincipalPerCollateralAmount(Q96 * 2);
        uint256 withCap = lenderCommitmentGroupV3.calculateCollateralTokensAmountEquivalentToPrincipalTokens(1000);
        assertEq(withCap, 500, "With cap should need 500");

        lenderCommitmentGroupV3.setMaxPrincipalPerCollateralAmount(0);
        uint256 afterReset = lenderCommitmentGroupV3.calculateCollateralTokensAmountEquivalentToPrincipalTokens(1000);
        assertEq(afterReset, 250, "After reset to 0 should use oracle (250)");
    }

    function test_setMaxPrincipalPerCollateralAmount_affects_collateralRequired() public {
        initialize_group_contract();
        lenderCommitmentGroupV3.set_useRealGetRequiredCollateral(true);

        // Oracle 1:1, collateralRatio = 10000 (100%)
        _mockPriceAdapter.setMockPriceRatioQ96(Q96);

        uint256 required = lenderCommitmentGroupV3.calculateCollateralRequiredToBorrowPrincipal(1000);
        assertEq(required, 1000, "Baseline: 1:1 price, 100% ratio = 1000");

        // Cap at 0.5:1 (half Q96) — means 1 collateral = 0.5 principal
        // So 1000 principal needs 2000 collateral base, * 100% ratio = 2000
        lenderCommitmentGroupV3.setMaxPrincipalPerCollateralAmount(Q96 / 2);

        required = lenderCommitmentGroupV3.calculateCollateralRequiredToBorrowPrincipal(1000);
        assertEq(required, 2000, "Cap at 0.5:1 should double required collateral");
    }

    // ============ Getters / Interface Tests ============

    function test_getCollateralTokenAddress() public {
        initialize_group_contract();
        assertEq(lenderCommitmentGroupV3.getCollateralTokenAddress(), address(collateralToken));
    }

    function test_getPrincipalTokenAddress() public {
        initialize_group_contract();
        assertEq(lenderCommitmentGroupV3.getPrincipalTokenAddress(), address(principalToken));
    }

    function test_getMarketId() public {
        initialize_group_contract();
        assertEq(lenderCommitmentGroupV3.getMarketId(), 1);
    }

    function test_getMaxLoanDuration() public {
        initialize_group_contract();
        assertEq(lenderCommitmentGroupV3.getMaxLoanDuration(), 5000000);
    }

    function test_asset() public {
        initialize_group_contract();
        assertEq(lenderCommitmentGroupV3.asset(), address(principalToken));
    }

    function test_getTokenDifferenceFromLiquidations() public {
        initialize_group_contract();
        assertEq(lenderCommitmentGroupV3.getTokenDifferenceFromLiquidations(), 0);

        lenderCommitmentGroupV3.set_tokenDifferenceFromLiquidations(-5000);
        assertEq(lenderCommitmentGroupV3.getTokenDifferenceFromLiquidations(), -5000);
    }

    // ============ Max Deposit/Mint/Withdraw/Redeem Tests ============

    function test_maxDeposit_returns_zero_when_paused() public {
        initialize_group_contract();
        lenderCommitmentGroupV3.force_set_firstDepositMade(true);

        _protocolPausingManager.addPauser(address(_tellerV2));
        vm.prank(address(_tellerV2));
        lenderCommitmentGroupV3.pausePool();

        uint256 maxDep = lenderCommitmentGroupV3.maxDeposit(address(lender));
        assertEq(maxDep, 0, "maxDeposit should be 0 when paused");
    }

    function test_maxDeposit_returns_zero_before_first_deposit_for_non_owner() public {
        initialize_group_contract();
        // firstDepositMade is false

        vm.prank(address(lender));
        uint256 maxDep = lenderCommitmentGroupV3.maxDeposit(address(lender));
        assertEq(maxDep, 0, "maxDeposit should be 0 before first deposit for non-owner");
    }

    function test_maxWithdraw_returns_zero_when_paused() public {
        initialize_group_contract();

        _protocolPausingManager.addPauser(address(_tellerV2));
        vm.prank(address(_tellerV2));
        lenderCommitmentGroupV3.pausePool();

        uint256 maxWith = lenderCommitmentGroupV3.maxWithdraw(address(lender));
        assertEq(maxWith, 0, "maxWithdraw should be 0 when paused");
    }

    function test_maxRedeem_returns_zero_within_delay() public {
        initialize_group_contract();

        vm.warp(1000);

        vm.prank(address(lenderCommitmentGroupV3));
        lenderCommitmentGroupV3.force_mint_shares(address(lender), 1000000);

        // Don't warp past delay
        uint256 maxRed = lenderCommitmentGroupV3.maxRedeem(address(lender));
        assertEq(maxRed, 0, "maxRedeem should be 0 within withdraw delay");
    }
}
