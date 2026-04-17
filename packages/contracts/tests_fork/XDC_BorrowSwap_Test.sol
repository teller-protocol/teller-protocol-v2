// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { BorrowSwap_G4 } from "../contracts/LenderCommitmentForwarder/extensions/rollover/BorrowSwap_G4.sol";
import { UniswapV3SwapAdapter } from "../contracts/LenderCommitmentForwarder/extensions/rollover/adapters/UniswapV3SwapAdapter.sol";

interface IUniswapV3Factory_XDC {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

/**
 * @title XDC BorrowSwap Fork Test
 * @notice Tests BorrowSwap_G4 + UniswapV3SwapAdapter on XDC Network with official Uniswap V3.
 *         Swap paths are passed as pre-encoded bytes, consistent with IPriceAdapter pattern.
 *
 * Run with:
 *   FOUNDRY_PROFILE=fork forge test --match-contract XDC_BorrowSwap_Test -vvvv \
 *     --fork-url https://rpc.xdc.org
 */
contract XDC_BorrowSwap_Test is Test {

    string constant NETWORK_NAME = "xdc";

    // XDC token addresses
    address constant WXDC = 0x951857744785E80e2De051c32EE7b25f9c458C42;
    address constant USDC = 0xfA2958CB79b0491CC627c1557F441eF849Ca8eb1; // Circle native USDC

    // Uniswap V3 contracts on XDC
    address constant UNISWAP_V3_FACTORY  = 0xcb2436774C3e191c85056d248EF4260ce5f27A9D;
    address constant UNISWAP_SWAP_ROUTER = 0xaa52bB8110fE38D0d2d2AF0B85C3A3eE622CA455;
    address constant UNISWAP_QUOTER_V2   = 0x5911cB3633e764939edc2d92b7e1ad375Bb57649;

    uint24 constant POOL_FEE_500   = 500;   // 0.05%
    uint24 constant POOL_FEE_3000  = 3000;  // 0.3%
    uint24 constant POOL_FEE_10000 = 10000; // 1%

    // G4 + adapter (deployed in setUp)
    UniswapV3SwapAdapter uniswapAdapter;
    BorrowSwap_G4 borrowSwapG4;

    address tellerV2;

    // Discovered pool fee tier
    uint24 activeFee;

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

        // Load TellerV2 from XDC deployment
        tellerV2 = getDeployedAddress("TellerV2");
        assertTrue(tellerV2.code.length > 0, "TellerV2 not deployed on XDC");

        // Deploy UniswapV3SwapAdapter configured for Uniswap V3 on XDC
        uniswapAdapter = new UniswapV3SwapAdapter(
            UNISWAP_SWAP_ROUTER,
            UNISWAP_QUOTER_V2
        );

        // Deploy BorrowSwap_G4 with the Uniswap adapter
        borrowSwapG4 = new BorrowSwap_G4(tellerV2, address(uniswapAdapter));

        console.log("TellerV2:", tellerV2);
        console.log("UniswapV3SwapAdapter:", address(uniswapAdapter));
        console.log("BorrowSwap_G4:", address(borrowSwapG4));

        // Discover active fee tier for USDC/WXDC
        activeFee = _findActiveFee(USDC, WXDC);
        console.log("Active USDC/WXDC fee tier:", activeFee);
    }

    // =========================================================================
    //  Helper: find active pool fee tier
    // =========================================================================

    function _findActiveFee(address tokenA, address tokenB) internal view returns (uint24) {
        IUniswapV3Factory_XDC factory = IUniswapV3Factory_XDC(UNISWAP_V3_FACTORY);
        uint24[] memory fees = new uint24[](3);
        fees[0] = POOL_FEE_500;
        fees[1] = POOL_FEE_3000;
        fees[2] = POOL_FEE_10000;

        for (uint i = 0; i < fees.length; i++) {
            address pool = factory.getPool(tokenA, tokenB, fees[i]);
            if (pool != address(0) && pool.code.length > 0) {
                return fees[i];
            }
        }
        revert("No USDC/WXDC pool found on Uniswap V3 (XDC)");
    }

    // =========================================================================
    //  Helper: build Uniswap V3 encoded paths
    // =========================================================================

    function _singleHopPath(address tokenIn, uint24 fee, address tokenOut)
        internal pure returns (bytes memory)
    {
        return abi.encodePacked(tokenIn, fee, tokenOut);
    }

    // =========================================================================
    //  Deployment & immutables verification
    // =========================================================================

    function test_G4_immutables() public {
        assertEq(address(borrowSwapG4.TELLER_V2()), tellerV2, "G4 should use XDC TellerV2");
        assertEq(
            address(borrowSwapG4.SWAP_ADAPTER()),
            address(uniswapAdapter),
            "G4 should point to Uniswap adapter"
        );
    }

    function test_adapter_immutables() public {
        assertEq(address(uniswapAdapter.SWAP_ROUTER()), UNISWAP_SWAP_ROUTER, "Adapter swap router");
        assertEq(address(uniswapAdapter.QUOTER()), UNISWAP_QUOTER_V2, "Adapter quoter");
    }

    // =========================================================================
    //  Uniswap V3 pool verification
    // =========================================================================

    function test_uniswap_pool_exists_USDC_WXDC() public {
        IUniswapV3Factory_XDC factory = IUniswapV3Factory_XDC(UNISWAP_V3_FACTORY);

        address pool500   = factory.getPool(USDC, WXDC, 500);
        address pool3000  = factory.getPool(USDC, WXDC, 3000);
        address pool10000 = factory.getPool(USDC, WXDC, 10000);

        console.log("USDC/WXDC pool (0.05%):", pool500);
        console.log("USDC/WXDC pool (0.3%):", pool3000);
        console.log("USDC/WXDC pool (1%):", pool10000);

        bool hasPool = pool500 != address(0) || pool3000 != address(0) || pool10000 != address(0);
        assertTrue(hasPool, "No Uniswap V3 USDC/WXDC pool found on XDC");
    }

    // =========================================================================
    //  G4 quote tests — bytes path through BorrowSwap_G4 -> adapter -> QuoterV2
    // =========================================================================

    function test_G4_quote_USDC_to_WXDC() public {
        bytes memory path = _singleHopPath(USDC, activeFee, WXDC);
        uint256 amountIn = 100 * 1e6; // USDC has 6 decimals

        uint256 amountOut = borrowSwapG4.quoteExactInput(path, amountIn);

        console.log("Quote 100 USDC -> WXDC:", amountOut);
        assertTrue(amountOut > 0, "Quote should return non-zero WXDC amount");
    }

    function test_G4_quote_WXDC_to_USDC() public {
        bytes memory path = _singleHopPath(WXDC, activeFee, USDC);
        uint256 amountIn = 100 ether; // WXDC has 18 decimals

        uint256 amountOut = borrowSwapG4.quoteExactInput(path, amountIn);

        console.log("Quote 100 WXDC -> USDC:", amountOut);
        assertTrue(amountOut > 0, "Quote should return non-zero USDC amount");
    }

    // =========================================================================
    //  Actual swap tests via the adapter
    // =========================================================================

    function test_swap_USDC_to_WXDC() public {
        uint256 amountIn = 100 * 1e6; // 100 USDC
        deal(USDC, address(this), amountIn);

        bytes memory path = _singleHopPath(USDC, activeFee, WXDC);

        // Quote first via G4
        uint256 expectedOut = borrowSwapG4.quoteExactInput(path, amountIn);
        console.log("Expected WXDC out:", expectedOut);
        assertTrue(expectedOut > 0, "Quote must be non-zero before swap");

        // Swap via adapter
        IERC20(USDC).approve(address(uniswapAdapter), amountIn);

        uint256 wxdcBefore = IERC20(WXDC).balanceOf(address(this));

        uint256 amountOut = uniswapAdapter.swap(
            path,
            amountIn,
            1, // amountOutMinimum
            address(this)
        );

        uint256 wxdcAfter = IERC20(WXDC).balanceOf(address(this));

        console.log("Swapped 100 USDC -> WXDC:", amountOut);
        console.log("WXDC balance delta:", wxdcAfter - wxdcBefore);

        assertTrue(amountOut > 0, "Swap should produce WXDC");
        assertEq(wxdcAfter - wxdcBefore, amountOut, "Balance delta should match amountOut");
        assertEq(IERC20(USDC).balanceOf(address(this)), 0, "All USDC should be consumed");
    }

    function test_swap_WXDC_to_USDC() public {
        uint256 amountIn = 100 ether; // 100 WXDC
        deal(WXDC, address(this), amountIn);

        bytes memory path = _singleHopPath(WXDC, activeFee, USDC);

        // Quote first
        uint256 expectedOut = borrowSwapG4.quoteExactInput(path, amountIn);
        console.log("Expected USDC out:", expectedOut);

        IERC20(WXDC).approve(address(uniswapAdapter), amountIn);

        uint256 usdcBefore = IERC20(USDC).balanceOf(address(this));

        uint256 amountOut = uniswapAdapter.swap(
            path,
            amountIn,
            1,
            address(this)
        );

        uint256 usdcAfter = IERC20(USDC).balanceOf(address(this));

        console.log("Swapped 100 WXDC -> USDC:", amountOut);
        assertTrue(amountOut > 0, "Swap should produce USDC");
        assertEq(usdcAfter - usdcBefore, amountOut, "Balance delta should match amountOut");
    }
}
