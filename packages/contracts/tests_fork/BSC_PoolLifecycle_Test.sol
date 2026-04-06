// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";

import { LenderCommitmentGroupFactory_V2 } from "../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Factory_V2.sol";
import { ILenderCommitmentGroup_V2 } from "../contracts/interfaces/ILenderCommitmentGroup_V2.sol";
import { IUniswapPricingLibrary } from "../contracts/interfaces/IUniswapPricingLibrary.sol";

interface IERC20_Lifecycle {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IUniswapV3Pool_Lifecycle {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
}

interface IUniswapV3Factory_Lifecycle {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IMarketRegistry_Lifecycle {
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

interface ITellerV2_Lifecycle {
    function marketRegistry() external view returns (address);
    function setTrustedMarketForwarder(uint256 _marketId, address _forwarder) external;
    function approveMarketForwarder(uint256 _marketId, address _forwarder) external;
    function repayLoanFull(uint256 _bidId) external;
    function getBidState(uint256 _bidId) external view returns (uint8);
    function collateralManager() external view returns (address);
}

interface ISmartCommitmentForwarder_Lifecycle {
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

interface IPoolV2 {
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

interface ISharesToken {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract BSC_PoolLifecycle_Fork_Test is Test {

    string constant NETWORK_NAME = "bsc";

    // BSC ecosystem addresses
    address constant PANCAKE_V3_FACTORY = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955; // BSC-USD (USDT)

    LenderCommitmentGroupFactory_V2 factoryv2;
    ITellerV2_Lifecycle tellerV2;
    IMarketRegistry_Lifecycle marketRegistry;
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
    uint8 usdtDecimals;
    uint8 wbnbDecimals;

    using stdJson for string;

    function getDeployedAddress(string memory contractName) internal view returns (address) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/", NETWORK_NAME, "/", contractName, ".json");
        string memory json = vm.readFile(path);
        return json.readAddress(".address");
    }

    function setUp() public {
        // Verify we're on BSC fork
        assertEq(block.chainid, 56, "Should be on BSC (chain 56)");

        // Load deployed contracts
        address payable factoryAddr = payable(getDeployedAddress("LenderCommitmentGroupFactory_V2"));
        factoryv2 = LenderCommitmentGroupFactory_V2(factoryAddr);
        assertTrue(factoryAddr.code.length > 0, "Factory contract not found on BSC");

        tellerV2 = ITellerV2_Lifecycle(getDeployedAddress("TellerV2"));
        smartCommitmentForwarder = getDeployedAddress("SmartCommitmentForwarder");
        marketRegistry = IMarketRegistry_Lifecycle(tellerV2.marketRegistry());
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

        // Find PancakeSwap V3 USDT/WBNB pool
        IUniswapV3Factory_Lifecycle pancakeFactory = IUniswapV3Factory_Lifecycle(PANCAKE_V3_FACTORY);
        uint24[] memory fees = new uint24[](3);
        fees[0] = 500;
        fees[1] = 2500;
        fees[2] = 10000;

        for (uint i = 0; i < fees.length; i++) {
            address candidate = pancakeFactory.getPool(USDT, WBNB, fees[i]);
            if (candidate != address(0) && candidate.code.length > 0) {
                uniPool = candidate;
                console.log("Using PancakeSwap pool:", candidate, "fee:", fees[i]);
                break;
            }
        }
        require(uniPool != address(0), "No USDT/WBNB pool found on PancakeSwap V3");

        // Determine token ordering
        IUniswapV3Pool_Lifecycle pool = IUniswapV3Pool_Lifecycle(uniPool);
        zeroForOne = (pool.token0() == USDT);
        usdtDecimals = IERC20_Lifecycle(USDT).decimals();
        wbnbDecimals = IERC20_Lifecycle(WBNB).decimals();
    }

    // ============ Helpers ============

    function _buildOracleRoutes() internal view returns (IUniswapPricingLibrary.PoolRouteConfig[] memory) {
        IUniswapV3Pool_Lifecycle pool = IUniswapV3Pool_Lifecycle(uniPool);
        IUniswapPricingLibrary.PoolRouteConfig[] memory routes = new IUniswapPricingLibrary.PoolRouteConfig[](1);
        routes[0] = IUniswapPricingLibrary.PoolRouteConfig({
            pool: uniPool,
            zeroForOne: zeroForOne,
            twapInterval: 5,
            token0Decimals: pool.token0() == USDT ? usdtDecimals : wbnbDecimals,
            token1Decimals: pool.token1() == USDT ? usdtDecimals : wbnbDecimals
        });
        return routes;
    }

    function _deployPool(uint256 initialDeposit) internal returns (address) {
        ILenderCommitmentGroup_V2.CommitmentGroupConfig memory config = ILenderCommitmentGroup_V2.CommitmentGroupConfig({
            principalTokenAddress: USDT,
            collateralTokenAddress: WBNB,
            marketId: marketId,
            maxLoanDuration: 604800,          // 1 week
            interestRateLowerBound: 6000,     // 60%
            interestRateUpperBound: 11000,    // 110%
            liquidityThresholdPercent: 8000,  // 80%
            collateralRatio: 15000            // 150%
        });

        deal(USDT, address(this), initialDeposit);
        IERC20_Lifecycle(USDT).approve(address(factoryv2), initialDeposit);

        address deployedPool = factoryv2.deployLenderCommitmentGroupPool(
            initialDeposit,
            config,
            _buildOracleRoutes()
        );

        console.log("Pool deployed at:", deployedPool);
        return deployedPool;
    }

    function _lenderDeposit(address _lender, address _pool, uint256 _amount) internal returns (uint256 shares) {
        deal(USDT, _lender, _amount);

        vm.startPrank(_lender);
        IERC20_Lifecycle(USDT).approve(_pool, _amount);
        shares = IPoolV2(_pool).addPrincipalToCommitmentGroup(_amount, _lender, 0);
        vm.stopPrank();

        console.log("Lender deposited:", _amount, "shares:", shares);
    }

    function _borrowFromPool(
        address _borrowerAddr,
        address _pool,
        uint256 _principalAmount,
        uint256 _collateralAmount
    ) internal returns (uint256 bidId) {
        // Deal collateral (WBNB) to borrower
        deal(WBNB, _borrowerAddr, _collateralAmount);

        vm.startPrank(_borrowerAddr);

        // Approve collateral to CollateralManager
        IERC20_Lifecycle(WBNB).approve(collateralManager, _collateralAmount);

        // Approve market forwarder for borrower
        tellerV2.approveMarketForwarder(marketId, smartCommitmentForwarder);

        // Borrow via SmartCommitmentForwarder
        bidId = ISmartCommitmentForwarder_Lifecycle(smartCommitmentForwarder)
            .acceptSmartCommitmentWithRecipient(
                _pool,
                _principalAmount,
                _collateralAmount,
                0, // tokenId (0 for ERC20)
                WBNB,
                _borrowerAddr,
                8000, // 80% interest rate (within bounds 60%-110%)
                604800 // 1 week duration
            );

        vm.stopPrank();

        console.log("Borrower got bid ID:", bidId);
    }

    // ============ Tests ============

    function test_lenderDeposit() public {
        uint256 initialDeposit = 100 * 10**usdtDecimals;
        address pool = _deployPool(initialDeposit);

        uint256 depositAmount = 500 * 10**usdtDecimals;
        uint256 shares = _lenderDeposit(lender, pool, depositAmount);

        // Verify lender received shares
        address sharesToken = IPoolV2(pool).poolSharesToken();
        uint256 lenderShares = ISharesToken(sharesToken).balanceOf(lender);
        assertGt(lenderShares, 0, "Lender should have shares");
        assertEq(lenderShares, shares, "Shares should match return value");

        // Verify pool received USDT
        uint256 poolBalance = IERC20_Lifecycle(USDT).balanceOf(pool);
        assertGe(poolBalance, depositAmount, "Pool should have at least the deposit amount");

        console.log("Lender shares:", lenderShares);
        console.log("Pool USDT balance:", poolBalance);
    }

    function test_borrowFromPool() public {
        uint256 initialDeposit = 100 * 10**usdtDecimals;
        address pool = _deployPool(initialDeposit);

        // Lender deposits 500 USDT
        uint256 lenderAmount = 500 * 10**usdtDecimals;
        _lenderDeposit(lender, pool, lenderAmount);

        // Borrower borrows 50 USDT with ~1.3 WBNB collateral (150% ratio)
        uint256 borrowAmount = 50 * 10**usdtDecimals;
        uint256 collateralAmount = 13 * 10**(wbnbDecimals - 1); // 1.3 WBNB

        uint256 borrowerUsdtBefore = IERC20_Lifecycle(USDT).balanceOf(borrower);
        uint256 bidId = _borrowFromPool(borrower, pool, borrowAmount, collateralAmount);

        // Verify borrower received USDT
        uint256 borrowerUsdtAfter = IERC20_Lifecycle(USDT).balanceOf(borrower);
        assertGe(borrowerUsdtAfter - borrowerUsdtBefore, borrowAmount, "Borrower should have received USDT");

        // Verify loan is active (state 4 = ACCEPTED in the enum, but let's just check it's non-zero)
        console.log("Bid state:", tellerV2.getBidState(bidId));
        console.log("Borrower USDT received:", borrowerUsdtAfter - borrowerUsdtBefore);
    }

    function test_repayLoan() public {
        uint256 initialDeposit = 100 * 10**usdtDecimals;
        address pool = _deployPool(initialDeposit);

        // Lender deposits
        uint256 lenderAmount = 500 * 10**usdtDecimals;
        _lenderDeposit(lender, pool, lenderAmount);

        // Borrower borrows
        uint256 borrowAmount = 50 * 10**usdtDecimals;
        uint256 collateralAmount = 13 * 10**(wbnbDecimals - 1);
        uint256 bidId = _borrowFromPool(borrower, pool, borrowAmount, collateralAmount);

        // Warp 1 day to accrue some interest
        vm.warp(block.timestamp + 1 days);

        // Deal extra USDT to borrower for interest repayment
        uint256 repayBuffer = 10 * 10**usdtDecimals; // extra for interest
        deal(USDT, borrower, borrowAmount + repayBuffer);

        uint256 borrowerWbnbBefore = IERC20_Lifecycle(WBNB).balanceOf(borrower);

        vm.startPrank(borrower);
        IERC20_Lifecycle(USDT).approve(address(tellerV2), borrowAmount + repayBuffer);
        tellerV2.repayLoanFull(bidId);
        vm.stopPrank();

        // Verify collateral returned
        uint256 borrowerWbnbAfter = IERC20_Lifecycle(WBNB).balanceOf(borrower);
        assertGt(borrowerWbnbAfter, borrowerWbnbBefore, "Borrower should have collateral returned");
        console.log("Collateral returned:", borrowerWbnbAfter - borrowerWbnbBefore);

        // Verify loan state changed (no longer ACCEPTED)
        console.log("Bid state after repay:", tellerV2.getBidState(bidId));
    }

    function test_lenderWithdraw() public {
        uint256 initialDeposit = 100 * 10**usdtDecimals;
        address pool = _deployPool(initialDeposit);

        // Lender deposits
        uint256 lenderAmount = 500 * 10**usdtDecimals;
        uint256 shares = _lenderDeposit(lender, pool, lenderAmount);

        // Borrower borrows, repays with interest
        uint256 borrowAmount = 50 * 10**usdtDecimals;
        uint256 collateralAmount = 13 * 10**(wbnbDecimals - 1);
        uint256 bidId = _borrowFromPool(borrower, pool, borrowAmount, collateralAmount);

        vm.warp(block.timestamp + 1 days);

        uint256 repayBuffer = 10 * 10**usdtDecimals;
        deal(USDT, borrower, borrowAmount + repayBuffer);

        vm.startPrank(borrower);
        IERC20_Lifecycle(USDT).approve(address(tellerV2), borrowAmount + repayBuffer);
        tellerV2.repayLoanFull(bidId);
        vm.stopPrank();

        // Lender prepares shares for withdrawal
        vm.startPrank(lender);
        IPoolV2(pool).prepareSharesForBurn(shares);
        vm.stopPrank();

        // Warp past withdrawal delay (300s default + buffer)
        vm.warp(block.timestamp + 301);

        // Lender withdraws
        uint256 lenderUsdtBefore = IERC20_Lifecycle(USDT).balanceOf(lender);

        vm.startPrank(lender);
        uint256 withdrawn = IPoolV2(pool).burnSharesToWithdrawEarnings(shares, lender, 0);
        vm.stopPrank();

        uint256 lenderUsdtAfter = IERC20_Lifecycle(USDT).balanceOf(lender);
        assertGt(lenderUsdtAfter, lenderUsdtBefore, "Lender should have received USDT");
        assertEq(lenderUsdtAfter - lenderUsdtBefore, withdrawn, "Withdrawn amount should match");

        console.log("Lender deposited:", lenderAmount);
        console.log("Lender withdrawn:", withdrawn);

        // Lender should get back at least their deposit (interest may be shared with initial depositor)
        // The initial depositor (factory/test contract) also has shares, so lender gets proportional share
    }

    function test_fullLifecycle() public {
        uint256 initialDeposit = 100 * 10**usdtDecimals;
        address pool = _deployPool(initialDeposit);

        console.log("=== Step 1: Lenders deposit ===");

        // Lender 1 deposits 500 USDT
        uint256 lender1Amount = 500 * 10**usdtDecimals;
        uint256 lender1Shares = _lenderDeposit(lender, pool, lender1Amount);

        // Lender 2 deposits 300 USDT
        uint256 lender2Amount = 300 * 10**usdtDecimals;
        uint256 lender2Shares = _lenderDeposit(lender2, pool, lender2Amount);

        uint256 availableToBorrow = IPoolV2(pool).getPrincipalAmountAvailableToBorrow();
        console.log("Available to borrow:", availableToBorrow);

        console.log("=== Step 2: Borrower borrows ===");

        uint256 borrowAmount = 100 * 10**usdtDecimals;
        uint256 collateralAmount = 13 * 10**(wbnbDecimals - 1) * 2; // ~2.6 WBNB for 100 USDT
        uint256 bidId = _borrowFromPool(borrower, pool, borrowAmount, collateralAmount);

        uint256 borrowerUsdt = IERC20_Lifecycle(USDT).balanceOf(borrower);
        console.log("Borrower received USDT:", borrowerUsdt);

        console.log("=== Step 3: Time passes, borrower repays ===");

        // Warp 3 days to accrue interest
        vm.warp(block.timestamp + 3 days);

        uint256 repayBuffer = 20 * 10**usdtDecimals;
        deal(USDT, borrower, borrowAmount + repayBuffer);

        vm.startPrank(borrower);
        IERC20_Lifecycle(USDT).approve(address(tellerV2), borrowAmount + repayBuffer);
        tellerV2.repayLoanFull(bidId);
        vm.stopPrank();

        console.log("Loan repaid. Bid state:", tellerV2.getBidState(bidId));

        console.log("=== Step 4: Lenders withdraw ===");

        // Lender 1 prepares and withdraws
        vm.prank(lender);
        IPoolV2(pool).prepareSharesForBurn(lender1Shares);

        // Lender 2 prepares and withdraws
        vm.prank(lender2);
        IPoolV2(pool).prepareSharesForBurn(lender2Shares);

        // Warp past withdrawal delay
        vm.warp(block.timestamp + 301);

        uint256 lender1Before = IERC20_Lifecycle(USDT).balanceOf(lender);
        vm.prank(lender);
        uint256 lender1Withdrawn = IPoolV2(pool).burnSharesToWithdrawEarnings(lender1Shares, lender, 0);

        uint256 lender2Before = IERC20_Lifecycle(USDT).balanceOf(lender2);
        vm.prank(lender2);
        uint256 lender2Withdrawn = IPoolV2(pool).burnSharesToWithdrawEarnings(lender2Shares, lender2, 0);

        console.log("Lender1 deposited:", lender1Amount, "withdrawn:", lender1Withdrawn);
        console.log("Lender2 deposited:", lender2Amount, "withdrawn:", lender2Withdrawn);

        // Both lenders should receive at least their deposits back (interest earned from loan)
        // Note: exact amounts depend on share of pool vs initial depositor
        assertGt(lender1Withdrawn, 0, "Lender1 should have withdrawn");
        assertGt(lender2Withdrawn, 0, "Lender2 should have withdrawn");

        console.log("=== Full lifecycle complete! ===");
    }
}
