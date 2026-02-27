// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";

import { LenderCommitmentGroupFactory_V2 } from "../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Factory_V2.sol";
import { ILenderCommitmentGroup_V2 } from "../contracts/interfaces/ILenderCommitmentGroup_V2.sol";
import { IUniswapPricingLibrary } from "../contracts/interfaces/IUniswapPricingLibrary.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @notice Algebra (Camelot V3) factory interface — no fee parameter, uses poolByPair
interface IAlgebraFactory {
    function poolByPair(address tokenA, address tokenB) external view returns (address pool);
}

/// @notice Algebra pool interface — uses globalState() instead of slot0(), getTimepoints() instead of observe()
interface IAlgebraPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    /// @dev Algebra V1 globalState has 8 return values (not 6 like Algebra Integral)
    function globalState() external view returns (
        uint160 price,              // sqrt(token1/token0) * 2^96
        int24 tick,                 // current tick
        uint16 feeZto,              // fee for zero-to-one swaps
        uint16 feeOtz,              // fee for one-to-zero swaps
        uint16 timepointIndex,      // oracle timepoint index
        uint8 communityFeeToken0,   // community fee for token0
        uint8 communityFeeToken1,   // community fee for token1
        bool unlocked               // reentrancy lock
    );
    function getTimepoints(uint32[] calldata secondsAgos) external view returns (
        int56[] memory tickCumulatives,
        uint160[] memory secondsPerLiquidityCumulatives
    );
}

/// @notice Standard Uniswap V3 pool interface — what Teller's UniswapPricingLibraryV2 expects
interface IUniswapV3Pool {
    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );
    function observe(uint32[] calldata secondsAgos) external view returns (
        int56[] memory tickCumulatives,
        uint160[] memory secondsPerLiquidityCumulativeX128s
    );
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IMarketRegistry {
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

interface ITellerV2 {
    function marketRegistry() external view returns (address);
    function setTrustedMarketForwarder(uint256 _marketId, address _forwarder) external;
}

contract ApeChain_DeployPool_Fork_Test is Test {

    string constant NETWORK_NAME = "apechain";

    // ApeChain ecosystem addresses
    address constant CAMELOT_V3_FACTORY = 0x10aA510d94E094Bd643677bd2964c3EE085Daffc; // Algebra factory
    address constant WAPE = 0x48b62137EdfA95a428D35C09E44256a739F6B557;
    address constant ApeUSD = 0xA2235d059F80e176D931Ef76b6C51953Eb3fBEf4;

    LenderCommitmentGroupFactory_V2 factoryv2;
    ITellerV2 tellerV2;
    IMarketRegistry marketRegistry;
    address smartCommitmentForwarder;

    uint256 marketId;

    using stdJson for string;

    function getDeployedAddress(string memory contractName) internal view returns (address) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/", NETWORK_NAME, "/", contractName, ".json");
        string memory json = vm.readFile(path);
        return json.readAddress(".address");
    }

    function setUp() public {
        console.log("Chain ID:", block.chainid);
        console.log("Block number:", block.number);

        // Load deployed contracts
        address payable factoryAddr = payable(getDeployedAddress("LenderCommitmentGroupFactory_V2"));
        factoryv2 = LenderCommitmentGroupFactory_V2(factoryAddr);
        assertTrue(factoryAddr.code.length > 0, "Factory contract not found on ApeChain");

        tellerV2 = ITellerV2(getDeployedAddress("TellerV2"));
        smartCommitmentForwarder = getDeployedAddress("SmartCommitmentForwarder");
        marketRegistry = IMarketRegistry(tellerV2.marketRegistry());

        console.log("Factory:", factoryAddr);
        console.log("TellerV2:", address(tellerV2));
        console.log("SmartCommitmentForwarder:", smartCommitmentForwarder);
        console.log("MarketRegistry:", address(marketRegistry));

        // Create a market
        address marketOwner = address(this);
        marketId = marketRegistry.createMarket(
            marketOwner,
            2592000,
            2592000,
            86400,
            0,
            false,
            false,
            ""
        );
        console.log("Created market ID:", marketId);

        tellerV2.setTrustedMarketForwarder(marketId, smartCommitmentForwarder);
    }

    function test_verifyApeChainDeployments() public {
        address collateralManager = getDeployedAddress("CollateralManager");
        assertTrue(address(tellerV2).code.length > 0, "TellerV2 not deployed");
        assertTrue(smartCommitmentForwarder.code.length > 0, "SmartCommitmentForwarder not deployed");
        assertTrue(collateralManager.code.length > 0, "CollateralManager not deployed");

        // ApeChain also has BorrowSwap (unlike BSC)
        address borrowSwap = getDeployedAddress("BorrowSwap");
        assertTrue(borrowSwap.code.length > 0, "BorrowSwap not deployed");

        console.log("All core contracts verified on ApeChain");
    }

    function test_verifyCamelotV3Pool() public {
        IAlgebraFactory factory = IAlgebraFactory(CAMELOT_V3_FACTORY);

        // Camelot V3 (Algebra) uses poolByPair — no fee tiers
        address pool = factory.poolByPair(WAPE, ApeUSD);
        console.log("WAPE/ApeUSD Camelot V3 pool:", pool);
        assertTrue(pool != address(0), "No Camelot V3 WAPE/ApeUSD pool found");

        // Verify tokens
        IAlgebraPool algebraPool = IAlgebraPool(pool);
        console.log("token0:", algebraPool.token0());
        console.log("token1:", algebraPool.token1());

        // globalState() works on Algebra pools
        (uint160 price,, uint16 feeZto,, uint16 timepointIndex,,, bool unlocked) = algebraPool.globalState();
        console.log("=== globalState() works (Algebra V1 - 8 return values) ===");
        console.log("sqrtPrice:", price);
        console.log("feeZto:", uint256(feeZto));
        console.log("timepointIndex:", uint256(timepointIndex));
        console.log("unlocked:", unlocked);
        assertGt(price, 0, "Price should be non-zero");

        // getTimepoints() works on Algebra pools (same as observe())
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = 5;
        secondsAgos[1] = 0;
        (int56[] memory tickCumulatives, ) = algebraPool.getTimepoints(secondsAgos);
        console.log("=== getTimepoints() works ===");
        assertTrue(tickCumulatives.length == 2, "Should return 2 tick cumulatives");
    }

    /// @notice This test DEMONSTRATES the incompatibility — slot0() reverts on Camelot V3
    function test_slot0_REVERTS_on_CamelotV3() public {
        IAlgebraFactory factory = IAlgebraFactory(CAMELOT_V3_FACTORY);
        address pool = factory.poolByPair(WAPE, ApeUSD);

        // slot0() does NOT exist on Algebra pools — this WILL revert
        IUniswapV3Pool uniPool = IUniswapV3Pool(pool);
        vm.expectRevert();
        uniPool.slot0();

        console.log("CONFIRMED: slot0() reverts on Camelot V3 (Algebra) pools");
    }

    /// @notice This test DEMONSTRATES the incompatibility — observe() reverts on Camelot V3
    function test_observe_REVERTS_on_CamelotV3() public {
        IAlgebraFactory factory = IAlgebraFactory(CAMELOT_V3_FACTORY);
        address pool = factory.poolByPair(WAPE, ApeUSD);

        // observe() does NOT exist on Algebra pools — this WILL revert
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = 5;
        secondsAgos[1] = 0;

        IUniswapV3Pool uniPool = IUniswapV3Pool(pool);
        vm.expectRevert();
        uniPool.observe(secondsAgos);

        console.log("CONFIRMED: observe() reverts on Camelot V3 (Algebra) pools");
    }

    /// @notice Pool deployment succeeds because the factory does NOT call the pricing
    ///         library during initialization. The oracle is only invoked during borrow/liquidation.
    function test_deployPoolV2_on_CamelotV3() public {
        IAlgebraFactory factory = IAlgebraFactory(CAMELOT_V3_FACTORY);
        address pool = factory.poolByPair(WAPE, ApeUSD);
        require(pool != address(0), "No WAPE/ApeUSD pool");

        IAlgebraPool algebraPool = IAlgebraPool(pool);
        address token0 = algebraPool.token0();
        bool zeroForOne = (token0 == ApeUSD);

        uint8 apeUsdDecimals = IERC20(ApeUSD).decimals();
        uint8 wapeDecimals = IERC20(WAPE).decimals();

        console.log("token0:", token0);
        console.log("zeroForOne:", zeroForOne);
        console.log("ApeUSD decimals:", apeUsdDecimals, "WAPE decimals:", wapeDecimals);

        // Oracle route config — this points to a Camelot V3 (Algebra) pool
        // The pool address is valid, but UniswapPricingLibraryV2 will try to call
        // slot0()/observe() on it, which will revert
        IUniswapPricingLibrary.PoolRouteConfig[] memory routes = new IUniswapPricingLibrary.PoolRouteConfig[](1);
        routes[0] = IUniswapPricingLibrary.PoolRouteConfig({
            pool: pool,
            zeroForOne: zeroForOne,
            twapInterval: 5,
            token0Decimals: algebraPool.token0() == ApeUSD ? apeUsdDecimals : wapeDecimals,
            token1Decimals: algebraPool.token1() == ApeUSD ? apeUsdDecimals : wapeDecimals
        });

        ILenderCommitmentGroup_V2.CommitmentGroupConfig memory config = ILenderCommitmentGroup_V2.CommitmentGroupConfig({
            principalTokenAddress: ApeUSD,
            collateralTokenAddress: WAPE,
            marketId: marketId,
            maxLoanDuration: 604800,
            interestRateLowerBound: 6000,
            interestRateUpperBound: 11000,
            liquidityThresholdPercent: 8000,
            collateralRatio: 15000
        });

        uint256 initialDeposit = 100 * 10**apeUsdDecimals;

        // ApeUSD is a yield-bearing rebasing token - deal() can't find its balance slot.
        // Transfer from the Camelot pool which holds ApeUSD liquidity.
        address apeUsdWhale = pool; // Camelot pool holds ApeUSD
        uint256 whaleBalance = IERC20(ApeUSD).balanceOf(apeUsdWhale);
        require(whaleBalance >= initialDeposit, "Whale has insufficient ApeUSD");
        vm.prank(apeUsdWhale);
        IERC20(ApeUSD).transfer(address(this), initialDeposit);

        IERC20(ApeUSD).approve(address(factoryv2), initialDeposit);

        // Pool deployment SUCCEEDS - the pricing library is NOT called during init.
        // The oracle (slot0/observe) is only invoked during borrow (collateral pricing)
        // and liquidation operations.
        console.log("Deploying pool...");
        address deployedPool = factoryv2.deployLenderCommitmentGroupPool(
            initialDeposit,
            config,
            routes
        );

        assertTrue(deployedPool != address(0), "Pool should be deployed");
        assertTrue(deployedPool.code.length > 0, "Pool should have code");
        console.log("=== PoolV2 deployed at:", deployedPool, "===");
        console.log("NOTE: Pool deploys OK, but borrowing will fail when oracle is invoked");
    }
}
