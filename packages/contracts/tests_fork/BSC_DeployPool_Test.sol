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

interface IUniswapV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );
}

interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IMarketRegistry {
    function getMarketOwner(uint256 marketId) external view returns (address);
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
    function approveMarketForwarder(uint256 _marketId, address _forwarder) external;
}

contract BSC_DeployPool_Fork_Test is Test {

    string constant NETWORK_NAME = "bsc";

    // BSC ecosystem addresses
    address constant PANCAKE_V3_FACTORY = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955; // BSC-USD (USDT)

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

        // Verify we're on BSC fork
        assertEq(block.chainid, 56, "Should be on BSC (chain 56)");

        address payable factoryAddr = payable(getDeployedAddress("LenderCommitmentGroupFactory_V2"));
        factoryv2 = LenderCommitmentGroupFactory_V2(factoryAddr);
        assertTrue(factoryAddr.code.length > 0, "Factory contract not found on BSC");

        tellerV2 = ITellerV2(getDeployedAddress("TellerV2"));
        smartCommitmentForwarder = getDeployedAddress("SmartCommitmentForwarder");
        marketRegistry = IMarketRegistry(tellerV2.marketRegistry());

        console.log("Factory:", factoryAddr);
        console.log("TellerV2:", address(tellerV2));
        console.log("SmartCommitmentForwarder:", smartCommitmentForwarder);
        console.log("MarketRegistry:", address(marketRegistry));

        // Create a market on BSC (no markets exist yet)
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

        // Set SmartCommitmentForwarder as trusted forwarder for this market
        tellerV2.setTrustedMarketForwarder(marketId, smartCommitmentForwarder);
        console.log("Set trusted market forwarder");
    }

    function test_verifyBSCDeployments() public {
        address collateralManager = getDeployedAddress("CollateralManager");
        assertTrue(address(tellerV2).code.length > 0, "TellerV2 not deployed");
        assertTrue(smartCommitmentForwarder.code.length > 0, "SmartCommitmentForwarder not deployed");
        assertTrue(collateralManager.code.length > 0, "CollateralManager not deployed");
        console.log("All core contracts verified on BSC");
    }

    function test_verifyPancakeSwapPool() public {
        IUniswapV3Factory factory = IUniswapV3Factory(PANCAKE_V3_FACTORY);

        address pool500 = factory.getPool(USDT, WBNB, 500);
        address pool2500 = factory.getPool(USDT, WBNB, 2500);
        address pool10000 = factory.getPool(USDT, WBNB, 10000);

        console.log("USDT/WBNB pool (0.05%):", pool500);
        console.log("USDT/WBNB pool (0.25%):", pool2500);
        console.log("USDT/WBNB pool (1%):", pool10000);

        bool hasPool = pool500 != address(0) || pool2500 != address(0) || pool10000 != address(0);
        assertTrue(hasPool, "No PancakeSwap V3 USDT/WBNB pool found");
    }

    function test_deployPoolV2() public {
        // Find a valid PancakeSwap V3 pool for USDT/WBNB oracle route
        IUniswapV3Factory pancakeFactory = IUniswapV3Factory(PANCAKE_V3_FACTORY);

        address uniPool;
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
        IUniswapV3Pool pool = IUniswapV3Pool(uniPool);
        address token0 = pool.token0();
        address token1 = pool.token1();
        bool zeroForOne = (token0 == USDT);

        uint8 usdtDecimals = IERC20(USDT).decimals();
        uint8 wbnbDecimals = IERC20(WBNB).decimals();

        console.log("token0:", token0, "token1:", token1);
        console.log("zeroForOne:", zeroForOne);
        console.log("USDT decimals:", usdtDecimals, "WBNB decimals:", wbnbDecimals);

        // Oracle route: single hop USDT <-> WBNB
        IUniswapPricingLibrary.PoolRouteConfig[] memory routes = new IUniswapPricingLibrary.PoolRouteConfig[](1);
        routes[0] = IUniswapPricingLibrary.PoolRouteConfig({
            pool: uniPool,
            zeroForOne: zeroForOne,
            twapInterval: 5,
            token0Decimals: pool.token0() == USDT ? usdtDecimals : wbnbDecimals,
            token1Decimals: pool.token1() == USDT ? usdtDecimals : wbnbDecimals
        });

        // Pool config: USDT principal, WBNB collateral
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

        // Fund with USDT
        uint256 initialDeposit = 100 * 10**usdtDecimals; // 100 USDT
        deal(USDT, address(this), initialDeposit);

        console.log("USDT balance:", IERC20(USDT).balanceOf(address(this)));

        // Approve factory
        IERC20(USDT).approve(address(factoryv2), initialDeposit);

        // Deploy the pool!
        address deployedPool = factoryv2.deployLenderCommitmentGroupPool(
            initialDeposit,
            config,
            routes
        );

        console.log("=== PoolV2 deployed at:", deployedPool, "===");
        assertTrue(deployedPool != address(0), "Pool should be deployed");
        assertTrue(deployedPool.code.length > 0, "Deployed pool should have code");

        // Verify we can read pool state
        console.log("Pool deployment and verification successful!");
    }
}
