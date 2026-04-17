// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { BorrowSwap_G4 } from "../contracts/LenderCommitmentForwarder/extensions/rollover/BorrowSwap_G4.sol";
import { UniswapV3SwapAdapter } from "../contracts/LenderCommitmentForwarder/extensions/rollover/adapters/UniswapV3SwapAdapter.sol";

interface IUniswapV3Factory_BSC {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

/**
 * @title BSC BorrowSwap Fork Test
 * @notice Tests BorrowSwap_G4 + UniswapV3SwapAdapter on BNB Chain with PancakeSwap V3.
 *         Swap paths are passed as pre-encoded bytes, consistent with IPriceAdapter pattern.
 *
 * Run with:
 *   FOUNDRY_PROFILE=fork forge test --match-contract BSC_BorrowSwap_Test -vvvv \
 *     --fork-url https://bsc-dataseed1.binance.org
 */
contract BSC_BorrowSwap_Test is Test {

    string constant NETWORK_NAME = "bsc";

    // BSC token addresses
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955; // BSC-USD (USDT)
    address constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

    // PancakeSwap V3 contracts on BSC
    address constant PANCAKE_V3_FACTORY    = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;
    address constant PANCAKE_SWAP_ROUTER   = 0x1b81D678ffb9C0263b24A97847620C99d213eB14;
    address constant PANCAKE_QUOTER_V2     = 0xB048Bbc1Ee6b733FFfCFb9e9CeF7375518e25997;

    uint24 constant POOL_FEE_500  = 500;   // 0.05%
    uint24 constant POOL_FEE_2500 = 2500;  // 0.25%

    // G4 + adapter (deployed in setUp)
    UniswapV3SwapAdapter pancakeAdapter;
    BorrowSwap_G4 borrowSwapG4;

    address tellerV2;

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

        // Load TellerV2 from BSC deployment
        tellerV2 = getDeployedAddress("TellerV2");
        assertTrue(tellerV2.code.length > 0, "TellerV2 not deployed on BSC");

        // Deploy UniswapV3SwapAdapter configured for PancakeSwap V3
        pancakeAdapter = new UniswapV3SwapAdapter(
            PANCAKE_SWAP_ROUTER,
            PANCAKE_QUOTER_V2
        );

        // Deploy BorrowSwap_G4 with the PancakeSwap adapter
        borrowSwapG4 = new BorrowSwap_G4(tellerV2, address(pancakeAdapter));

        console.log("TellerV2:", tellerV2);
        console.log("UniswapV3SwapAdapter (PancakeSwap):", address(pancakeAdapter));
        console.log("BorrowSwap_G4:", address(borrowSwapG4));
    }

    // =========================================================================
    //  Helper: build Uniswap V3 encoded paths
    // =========================================================================

    function _singleHopPath(address tokenIn, uint24 fee, address tokenOut)
        internal pure returns (bytes memory)
    {
        return abi.encodePacked(tokenIn, fee, tokenOut);
    }

    function _multiHopPath(address tokenIn, uint24 fee0, address intermediate, uint24 fee1, address tokenOut)
        internal pure returns (bytes memory)
    {
        return abi.encodePacked(tokenIn, fee0, intermediate, fee1, tokenOut);
    }

    // =========================================================================
    //  Deployment & immutables verification
    // =========================================================================

    function test_G4_immutables() public {
        assertEq(address(borrowSwapG4.TELLER_V2()), tellerV2, "G4 should use BSC TellerV2");
        assertEq(
            address(borrowSwapG4.SWAP_ADAPTER()),
            address(pancakeAdapter),
            "G4 should point to PancakeSwap adapter"
        );
    }

    function test_adapter_immutables() public {
        assertEq(address(pancakeAdapter.SWAP_ROUTER()), PANCAKE_SWAP_ROUTER, "Adapter swap router");
        assertEq(address(pancakeAdapter.QUOTER()), PANCAKE_QUOTER_V2, "Adapter quoter");
    }

    // =========================================================================
    //  PancakeSwap V3 pool verification
    // =========================================================================

    function test_pancake_pool_exists_USDT_WBNB() public {
        IUniswapV3Factory_BSC factory = IUniswapV3Factory_BSC(PANCAKE_V3_FACTORY);

        address pool500  = factory.getPool(USDT, WBNB, 500);
        address pool2500 = factory.getPool(USDT, WBNB, 2500);
        address pool10000 = factory.getPool(USDT, WBNB, 10000);

        console.log("USDT/WBNB pool (0.05%):", pool500);
        console.log("USDT/WBNB pool (0.25%):", pool2500);
        console.log("USDT/WBNB pool (1%):", pool10000);

        bool hasPool = pool500 != address(0) || pool2500 != address(0) || pool10000 != address(0);
        assertTrue(hasPool, "No PancakeSwap V3 USDT/WBNB pool found");
    }

    // =========================================================================
    //  G4 quote tests — bytes path through BorrowSwap_G4 -> adapter -> QuoterV2
    // =========================================================================

    function test_G4_quote_USDT_to_WBNB() public {
        bytes memory path = _singleHopPath(USDT, POOL_FEE_2500, WBNB);
        uint256 amountIn = 100 * 1e18;

        uint256 amountOut = borrowSwapG4.quoteExactInput(path, amountIn);

        console.log("Quote 100 USDT -> WBNB:", amountOut);
        assertTrue(amountOut > 0, "Quote should return non-zero WBNB amount");
    }

    function test_G4_quote_WBNB_to_USDT() public {
        bytes memory path = _singleHopPath(WBNB, POOL_FEE_2500, USDT);
        uint256 amountIn = 1 ether;

        uint256 amountOut = borrowSwapG4.quoteExactInput(path, amountIn);

        console.log("Quote 1 WBNB -> USDT:", amountOut);
        assertTrue(amountOut > 0, "Quote should return non-zero USDT amount");
    }

    function test_G4_quote_USDT_to_WBNB_different_fee() public {
        // Caller can pick any fee tier — no DEFAULT_POOL_FEE constraint
        bytes memory path = _singleHopPath(USDT, POOL_FEE_500, WBNB);
        uint256 amountIn = 100 * 1e18;

        uint256 amountOut = borrowSwapG4.quoteExactInput(path, amountIn);

        console.log("Quote 100 USDT -> WBNB (0.05% fee):", amountOut);
        assertTrue(amountOut > 0, "Quote should return non-zero WBNB amount at 0.05% fee");
    }

    function test_G4_quote_multihop_USDC_to_USDT_via_WBNB() public {
        bytes memory path = _multiHopPath(USDC, POOL_FEE_2500, WBNB, POOL_FEE_2500, USDT);
        uint256 amountIn = 100 * 1e18;

        uint256 amountOut = borrowSwapG4.quoteExactInput(path, amountIn);

        console.log("Quote 100 USDC -> WBNB -> USDT:", amountOut);
        assertTrue(amountOut > 0, "Multi-hop quote should return non-zero USDT amount");
    }

    // =========================================================================
    //  Actual swap tests via the adapter
    // =========================================================================

    function test_swap_USDT_to_WBNB() public {
        uint256 amountIn = 100 * 1e18;
        deal(USDT, address(this), amountIn);

        bytes memory path = _singleHopPath(USDT, POOL_FEE_2500, WBNB);

        // Quote first via G4
        uint256 expectedOut = borrowSwapG4.quoteExactInput(path, amountIn);
        console.log("Expected WBNB out:", expectedOut);
        assertTrue(expectedOut > 0, "Quote must be non-zero before swap");

        // Swap via adapter
        IERC20(USDT).approve(address(pancakeAdapter), amountIn);

        uint256 wbnbBefore = IERC20(WBNB).balanceOf(address(this));

        uint256 amountOut = pancakeAdapter.swap(
            path,
            amountIn,
            1, // amountOutMinimum
            address(this)
        );

        uint256 wbnbAfter = IERC20(WBNB).balanceOf(address(this));

        console.log("Swapped 100 USDT -> WBNB:", amountOut);
        console.log("WBNB balance delta:", wbnbAfter - wbnbBefore);

        assertTrue(amountOut > 0, "Swap should produce WBNB");
        assertEq(wbnbAfter - wbnbBefore, amountOut, "Balance delta should match amountOut");
        assertEq(IERC20(USDT).balanceOf(address(this)), 0, "All USDT should be consumed");
    }

    function test_swap_WBNB_to_USDT() public {
        uint256 amountIn = 1 ether;
        deal(WBNB, address(this), amountIn);

        bytes memory path = _singleHopPath(WBNB, POOL_FEE_2500, USDT);

        // Quote first
        uint256 expectedOut = borrowSwapG4.quoteExactInput(path, amountIn);
        console.log("Expected USDT out:", expectedOut);

        IERC20(WBNB).approve(address(pancakeAdapter), amountIn);

        uint256 usdtBefore = IERC20(USDT).balanceOf(address(this));

        uint256 amountOut = pancakeAdapter.swap(
            path,
            amountIn,
            1,
            address(this)
        );

        uint256 usdtAfter = IERC20(USDT).balanceOf(address(this));

        console.log("Swapped 1 WBNB -> USDT:", amountOut);
        assertTrue(amountOut > 0, "Swap should produce USDT");
        assertEq(usdtAfter - usdtBefore, amountOut, "Balance delta should match amountOut");
    }

    function test_swap_multihop_USDC_to_USDT_via_WBNB() public {
        uint256 amountIn = 100 * 1e18;
        deal(USDC, address(this), amountIn);

        bytes memory path = _multiHopPath(USDC, POOL_FEE_2500, WBNB, POOL_FEE_2500, USDT);

        IERC20(USDC).approve(address(pancakeAdapter), amountIn);

        uint256 usdtBefore = IERC20(USDT).balanceOf(address(this));

        uint256 amountOut = pancakeAdapter.swap(
            path,
            amountIn,
            1,
            address(this)
        );

        uint256 usdtAfter = IERC20(USDT).balanceOf(address(this));

        console.log("Swapped 100 USDC -> WBNB -> USDT:", amountOut);
        assertTrue(amountOut > 0, "Multi-hop swap should produce USDT");
        assertEq(usdtAfter - usdtBefore, amountOut, "Balance delta should match amountOut");
    }
}
