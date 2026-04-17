// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";

import { LenderCommitmentGroupFactory_V2 } from "../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Factory_V2.sol";
import { ILenderCommitmentGroup_V2 } from "../contracts/interfaces/ILenderCommitmentGroup_V2.sol";
import { IUniswapPricingLibrary } from "../contracts/interfaces/IUniswapPricingLibrary.sol";

interface IERC20_XDC {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IUniswapV3Pool_XDC {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
}

interface IUniswapV3Factory_XDC {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IMarketRegistry_XDC {
    function createMarket(
        address _initialOwner,
        uint32 _paymentCycleDuration,
        uint32 _paymentDefaultDuration,
        uint32 _bidExpirationTime,
        uint16 _feePercent,
        bool _requireLenderAttestation,
        bool _requireBorrowerAttestation,
        string calldata _uri
    ) external returns (uint256 marketId_);
}

interface ITellerV2_XDC {
    function marketRegistry() external view returns (address);
    function setTrustedMarketForwarder(uint256 _marketId, address _forwarder) external;
    function approveMarketForwarder(uint256 _marketId, address _forwarder) external;
    function repayLoanFull(uint256 _bidId) external;
    function getBidState(uint256 _bidId) external view returns (uint8);
    function collateralManager() external view returns (address);
}

interface ISmartCommitmentForwarder_XDC {
    function acceptSmartCommitmentWithRecipient(
        address _smartCommitmentAddress,
        uint256 _principalAmount,
        uint256 _collateralAmount,
        uint256 _collateralTokenId,
        address _collateralTokenAddress,
        address _recipient,
        uint16 _interestRate,
        uint32 _loanDuration
    ) external returns (uint256 bidId);
}

interface IPoolV2_XDC {
    function addPrincipalToCommitmentGroup(
        uint256 _amount,
        address _sharesRecipient,
        uint256 _minSharesAmountOut
    ) external returns (uint256 sharesAmount_);

    function prepareSharesForBurn(
        uint256 _amountPoolSharesTokens
    ) external returns (bool);

    function burnSharesToWithdrawEarnings(
        uint256 _amountPoolSharesTokens,
        address _recipient,
        uint256 _minAmountOut
    ) external returns (uint256);

    function poolSharesToken() external view returns (address);
    function getPrincipalAmountAvailableToBorrow() external view returns (uint256);
    function getCollateralTokenType() external view returns (uint8);
    function getMarketId() external view returns (uint256);
    function getPrincipalTokenAddress() external view returns (address);
    function getCollateralTokenAddress() external view returns (address);
}

interface ISharesToken_XDC {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

/**
 * @title XDC Pool Lifecycle Fork Test
 * @notice End-to-end pool lifecycle test on XDC Network with official Uniswap V3.
 *         Tests: deploy pool, lender deposit, borrower borrow, repay, lender withdraw.
 *
 * Run with:
 *   FOUNDRY_PROFILE=fork forge test --match-contract XDC_PoolLifecycle_Fork_Test -vvvv \
 *     --fork-url https://rpc.xdc.org
 */
contract XDC_PoolLifecycle_Fork_Test is Test {

    string constant NETWORK_NAME = "xdc";

    // XDC ecosystem addresses
    address constant UNISWAP_V3_FACTORY = 0xcb2436774C3e191c85056d248EF4260ce5f27A9D;
    address constant WXDC = 0x951857744785E80e2De051c32EE7b25f9c458C42;
    address constant USDC = 0xfA2958CB79b0491CC627c1557F441eF849Ca8eb1; // Circle native USDC

    LenderCommitmentGroupFactory_V2 factoryv2;
    ITellerV2_XDC tellerV2;
    IMarketRegistry_XDC marketRegistry;
    address smartCommitmentForwarder;
    address collateralManager;

    uint256 marketId;

    // Test actors
    address lender = address(0xA001);
    address lender2 = address(0xA002);
    address borrower = address(0xB001);

    // Shared oracle route config (set in setUp)
    address uniPool;
    bool zeroForOne;
    uint8 usdcDecimals;
    uint8 wxdcDecimals;

    using stdJson for string;

    function getDeployedAddress(string memory contractName) internal view returns (address) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/", NETWORK_NAME, "/", contractName, ".json");
        string memory json = vm.readFile(path);
        return json.readAddress(".address");
    }

    function setUp() public {
        // Load deployed contracts
        address payable factoryAddr = payable(getDeployedAddress("LenderCommitmentGroupFactory_V2"));
        factoryv2 = LenderCommitmentGroupFactory_V2(factoryAddr);
        assertTrue(factoryAddr.code.length > 0, "Factory contract not found on XDC");

        tellerV2 = ITellerV2_XDC(getDeployedAddress("TellerV2"));
        smartCommitmentForwarder = getDeployedAddress("SmartCommitmentForwarder");
        marketRegistry = IMarketRegistry_XDC(tellerV2.marketRegistry());
        collateralManager = tellerV2.collateralManager();

        console.log("Factory:", factoryAddr);
        console.log("TellerV2:", address(tellerV2));
        console.log("SmartCommitmentForwarder:", smartCommitmentForwarder);
        console.log("CollateralManager:", collateralManager);

        // Create a market
        address marketOwner = address(this);
        marketId = marketRegistry.createMarket(
            marketOwner,
            2592000,  // 30 day payment cycle
            2592000,  // 30 day default duration
            86400,    // 1 day bid expiration
            0,        // 0% market fee
            false,    // no lender attestation
            false,    // no borrower attestation
            ""
        );
        console.log("Created market ID:", marketId);

        // Set SmartCommitmentForwarder as trusted forwarder
        tellerV2.setTrustedMarketForwarder(marketId, smartCommitmentForwarder);

        // Find Uniswap V3 USDC/WXDC pool
        IUniswapV3Factory_XDC uniFactory = IUniswapV3Factory_XDC(UNISWAP_V3_FACTORY);
        uint24[] memory fees = new uint24[](3);
        fees[0] = 500;
        fees[1] = 3000;
        fees[2] = 10000;

        for (uint i = 0; i < fees.length; i++) {
            address candidate = uniFactory.getPool(USDC, WXDC, fees[i]);
            if (candidate != address(0) && candidate.code.length > 0) {
                uniPool = candidate;
                console.log("Using Uniswap V3 pool:", candidate, "fee:", fees[i]);
                break;
            }
        }
        require(uniPool != address(0), "No USDC/WXDC pool found on Uniswap V3 (XDC)");

        // Determine token ordering
        IUniswapV3Pool_XDC pool = IUniswapV3Pool_XDC(uniPool);
        zeroForOne = (pool.token0() == USDC);
        usdcDecimals = IERC20_XDC(USDC).decimals();
        wxdcDecimals = IERC20_XDC(WXDC).decimals();
    }

    // ============ Helpers ============

    function _buildOracleRoutes() internal view returns (IUniswapPricingLibrary.PoolRouteConfig[] memory) {
        IUniswapV3Pool_XDC pool = IUniswapV3Pool_XDC(uniPool);
        IUniswapPricingLibrary.PoolRouteConfig[] memory routes = new IUniswapPricingLibrary.PoolRouteConfig[](1);
        routes[0] = IUniswapPricingLibrary.PoolRouteConfig({
            pool: uniPool,
            zeroForOne: zeroForOne,
            twapInterval: 5,
            token0Decimals: pool.token0() == USDC ? usdcDecimals : wxdcDecimals,
            token1Decimals: pool.token1() == USDC ? usdcDecimals : wxdcDecimals
        });
        return routes;
    }

    function _deployPool(uint256 initialDeposit) internal returns (address) {
        ILenderCommitmentGroup_V2.CommitmentGroupConfig memory config = ILenderCommitmentGroup_V2.CommitmentGroupConfig({
            principalTokenAddress: USDC,
            collateralTokenAddress: WXDC,
            marketId: marketId,
            maxLoanDuration: 604800,          // 1 week
            interestRateLowerBound: 6000,     // 60%
            interestRateUpperBound: 11000,    // 110%
            liquidityThresholdPercent: 8000,  // 80%
            collateralRatio: 15000            // 150%
        });

        deal(USDC, address(this), initialDeposit);
        IERC20_XDC(USDC).approve(address(factoryv2), initialDeposit);

        address deployedPool = factoryv2.deployLenderCommitmentGroupPool(
            initialDeposit,
            config,
            _buildOracleRoutes()
        );

        console.log("Pool deployed at:", deployedPool);
        return deployedPool;
    }

    function _lenderDeposit(address _lender, address _pool, uint256 _amount) internal returns (uint256 shares) {
        deal(USDC, _lender, _amount);

        vm.startPrank(_lender);
        IERC20_XDC(USDC).approve(_pool, _amount);
        shares = IPoolV2_XDC(_pool).addPrincipalToCommitmentGroup(_amount, _lender, 0);
        vm.stopPrank();

        console.log("Lender deposited:", _amount, "shares:", shares);
    }

    function _borrowFromPool(
        address _borrowerAddr,
        address _pool,
        uint256 _principalAmount,
        uint256 _collateralAmount
    ) internal returns (uint256 bidId) {
        // Deal collateral (WXDC) to borrower
        deal(WXDC, _borrowerAddr, _collateralAmount);

        vm.startPrank(_borrowerAddr);

        // Approve collateral to CollateralManager
        IERC20_XDC(WXDC).approve(collateralManager, _collateralAmount);

        // Approve market forwarder for borrower
        tellerV2.approveMarketForwarder(marketId, smartCommitmentForwarder);

        // Borrow via SmartCommitmentForwarder
        bidId = ISmartCommitmentForwarder_XDC(smartCommitmentForwarder)
            .acceptSmartCommitmentWithRecipient(
                _pool,
                _principalAmount,
                _collateralAmount,
                0, // tokenId (0 for ERC20)
                WXDC,
                _borrowerAddr,
                8000, // 80% interest rate (within bounds 60%-110%)
                604800 // 1 week duration
            );

        vm.stopPrank();

        console.log("Borrower got bid ID:", bidId);
    }

    // ============ Tests ============

    function test_lenderDeposit() public {
        uint256 initialDeposit = 100 * 10**usdcDecimals;
        address pool = _deployPool(initialDeposit);

        uint256 depositAmount = 500 * 10**usdcDecimals;
        uint256 shares = _lenderDeposit(lender, pool, depositAmount);

        // Verify lender received shares
        address sharesToken = IPoolV2_XDC(pool).poolSharesToken();
        uint256 lenderShares = ISharesToken_XDC(sharesToken).balanceOf(lender);
        assertGt(lenderShares, 0, "Lender should have shares");
        assertEq(lenderShares, shares, "Shares should match return value");

        // Verify pool received USDC
        uint256 poolBalance = IERC20_XDC(USDC).balanceOf(pool);
        assertGe(poolBalance, depositAmount, "Pool should have at least the deposit amount");

        console.log("Lender shares:", lenderShares);
        console.log("Pool USDC balance:", poolBalance);
    }

    function test_borrowFromPool() public {
        uint256 initialDeposit = 100 * 10**usdcDecimals;
        address pool = _deployPool(initialDeposit);

        // Lender deposits 500 USDC
        uint256 lenderAmount = 500 * 10**usdcDecimals;
        _lenderDeposit(lender, pool, lenderAmount);

        // Borrower borrows 50 USDC with WXDC collateral (150% ratio)
        uint256 borrowAmount = 50 * 10**usdcDecimals;
        uint256 collateralAmount = 1000 ether; // WXDC — adjust based on price

        uint256 borrowerUsdcBefore = IERC20_XDC(USDC).balanceOf(borrower);
        uint256 bidId = _borrowFromPool(borrower, pool, borrowAmount, collateralAmount);

        // Verify borrower received USDC
        uint256 borrowerUsdcAfter = IERC20_XDC(USDC).balanceOf(borrower);
        assertGe(borrowerUsdcAfter - borrowerUsdcBefore, borrowAmount, "Borrower should have received USDC");

        console.log("Bid state:", tellerV2.getBidState(bidId));
        console.log("Borrower USDC received:", borrowerUsdcAfter - borrowerUsdcBefore);
    }

    function test_repayLoan() public {
        uint256 initialDeposit = 100 * 10**usdcDecimals;
        address pool = _deployPool(initialDeposit);

        // Lender deposits
        uint256 lenderAmount = 500 * 10**usdcDecimals;
        _lenderDeposit(lender, pool, lenderAmount);

        // Borrower borrows
        uint256 borrowAmount = 50 * 10**usdcDecimals;
        uint256 collateralAmount = 1000 ether;
        uint256 bidId = _borrowFromPool(borrower, pool, borrowAmount, collateralAmount);

        // Warp 1 day to accrue some interest
        vm.warp(block.timestamp + 1 days);

        // Deal extra USDC to borrower for interest repayment
        uint256 repayBuffer = 10 * 10**usdcDecimals; // extra for interest
        deal(USDC, borrower, borrowAmount + repayBuffer);

        uint256 borrowerWxdcBefore = IERC20_XDC(WXDC).balanceOf(borrower);

        vm.startPrank(borrower);
        IERC20_XDC(USDC).approve(address(tellerV2), borrowAmount + repayBuffer);
        tellerV2.repayLoanFull(bidId);
        vm.stopPrank();

        // Verify collateral returned
        uint256 borrowerWxdcAfter = IERC20_XDC(WXDC).balanceOf(borrower);
        assertGt(borrowerWxdcAfter, borrowerWxdcBefore, "Borrower should have collateral returned");
        console.log("Collateral returned:", borrowerWxdcAfter - borrowerWxdcBefore);

        console.log("Bid state after repay:", tellerV2.getBidState(bidId));
    }

    function test_lenderWithdraw() public {
        uint256 initialDeposit = 100 * 10**usdcDecimals;
        address pool = _deployPool(initialDeposit);

        // Lender deposits
        uint256 lenderAmount = 500 * 10**usdcDecimals;
        uint256 shares = _lenderDeposit(lender, pool, lenderAmount);

        // Borrower borrows, repays with interest
        uint256 borrowAmount = 50 * 10**usdcDecimals;
        uint256 collateralAmount = 1000 ether;
        uint256 bidId = _borrowFromPool(borrower, pool, borrowAmount, collateralAmount);

        vm.warp(block.timestamp + 1 days);

        uint256 repayBuffer = 10 * 10**usdcDecimals;
        deal(USDC, borrower, borrowAmount + repayBuffer);

        vm.startPrank(borrower);
        IERC20_XDC(USDC).approve(address(tellerV2), borrowAmount + repayBuffer);
        tellerV2.repayLoanFull(bidId);
        vm.stopPrank();

        // Lender prepares shares for withdrawal
        vm.startPrank(lender);
        IPoolV2_XDC(pool).prepareSharesForBurn(shares);
        vm.stopPrank();

        // Warp past withdrawal delay (300s default + buffer)
        vm.warp(block.timestamp + 301);

        // Lender withdraws
        uint256 lenderUsdcBefore = IERC20_XDC(USDC).balanceOf(lender);

        vm.startPrank(lender);
        uint256 withdrawn = IPoolV2_XDC(pool).burnSharesToWithdrawEarnings(shares, lender, 0);
        vm.stopPrank();

        uint256 lenderUsdcAfter = IERC20_XDC(USDC).balanceOf(lender);
        assertGt(lenderUsdcAfter, lenderUsdcBefore, "Lender should have received USDC");
        assertEq(lenderUsdcAfter - lenderUsdcBefore, withdrawn, "Withdrawn amount should match");

        console.log("Lender deposited:", lenderAmount);
        console.log("Lender withdrawn:", withdrawn);
    }

    function test_fullLifecycle() public {
        uint256 initialDeposit = 100 * 10**usdcDecimals;
        address pool = _deployPool(initialDeposit);

        console.log("=== Step 1: Lenders deposit ===");

        // Lender 1 deposits 500 USDC
        uint256 lender1Amount = 500 * 10**usdcDecimals;
        uint256 lender1Shares = _lenderDeposit(lender, pool, lender1Amount);

        // Lender 2 deposits 300 USDC
        uint256 lender2Amount = 300 * 10**usdcDecimals;
        uint256 lender2Shares = _lenderDeposit(lender2, pool, lender2Amount);

        uint256 availableToBorrow = IPoolV2_XDC(pool).getPrincipalAmountAvailableToBorrow();
        console.log("Available to borrow:", availableToBorrow);

        console.log("=== Step 2: Borrower borrows ===");

        uint256 borrowAmount = 100 * 10**usdcDecimals;
        uint256 collateralAmount = 2000 ether; // WXDC for 100 USDC at 150% collateral
        uint256 bidId = _borrowFromPool(borrower, pool, borrowAmount, collateralAmount);

        uint256 borrowerUsdc = IERC20_XDC(USDC).balanceOf(borrower);
        console.log("Borrower received USDC:", borrowerUsdc);

        console.log("=== Step 3: Time passes, borrower repays ===");

        // Warp 3 days to accrue interest
        vm.warp(block.timestamp + 3 days);

        uint256 repayBuffer = 20 * 10**usdcDecimals;
        deal(USDC, borrower, borrowAmount + repayBuffer);

        vm.startPrank(borrower);
        IERC20_XDC(USDC).approve(address(tellerV2), borrowAmount + repayBuffer);
        tellerV2.repayLoanFull(bidId);
        vm.stopPrank();

        console.log("Loan repaid. Bid state:", tellerV2.getBidState(bidId));

        console.log("=== Step 4: Lenders withdraw ===");

        // Lender 1 prepares and withdraws
        vm.prank(lender);
        IPoolV2_XDC(pool).prepareSharesForBurn(lender1Shares);

        // Lender 2 prepares and withdraws
        vm.prank(lender2);
        IPoolV2_XDC(pool).prepareSharesForBurn(lender2Shares);

        // Warp past withdrawal delay
        vm.warp(block.timestamp + 301);

        vm.prank(lender);
        uint256 lender1Withdrawn = IPoolV2_XDC(pool).burnSharesToWithdrawEarnings(lender1Shares, lender, 0);

        vm.prank(lender2);
        uint256 lender2Withdrawn = IPoolV2_XDC(pool).burnSharesToWithdrawEarnings(lender2Shares, lender2, 0);

        console.log("Lender1 deposited:", lender1Amount, "withdrawn:", lender1Withdrawn);
        console.log("Lender2 deposited:", lender2Amount, "withdrawn:", lender2Withdrawn);

        assertGt(lender1Withdrawn, 0, "Lender1 should have withdrawn");
        assertGt(lender2Withdrawn, 0, "Lender2 should have withdrawn");

        console.log("=== Full lifecycle complete! ===");
    }
}
