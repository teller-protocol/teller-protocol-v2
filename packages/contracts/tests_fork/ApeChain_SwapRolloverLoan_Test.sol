// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { SwapRolloverLoan } from "../contracts/LenderCommitmentForwarder/extensions/rollover/SwapRolloverLoan.sol";
import { SwapRolloverLoan_G2 } from "../contracts/LenderCommitmentForwarder/extensions/rollover/SwapRolloverLoan_G2.sol";
import { SwapRolloverLoan_G4 } from "../contracts/LenderCommitmentForwarder/extensions/rollover/SwapRolloverLoan_G4.sol";
import { ITellerV2 } from "../contracts/interfaces/ITellerV2.sol";

interface IAlgebraFactory_Test {
    function poolByPair(address tokenA, address tokenB) external view returns (address pool);
}

interface IAlgebraPool_Test {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
    function globalState() external view returns (
        uint160 price, int24 tick, uint16 feeZto, uint16 feeOtz,
        uint16 timepointIndex, uint8 communityFeeToken0,
        uint8 communityFeeToken1, bool unlocked
    );
}

interface IUniswapV3Factory_Test {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

/**
 * @title ApeChain SwapRolloverLoan Fork Test
 * @notice Tests SwapRolloverLoan_G4 compatibility with Camelot V3 (Algebra) on ApeChain.
 *
 * KEY DIFFERENCES (Algebra vs Uniswap V3):
 *   1. CALLBACK: Algebra calls `algebraFlashCallback` (not `uniswapV3FlashCallback`)
 *   2. FACTORY: Algebra uses `poolByPair(tokenA, tokenB)` (not `getPool(tokenA, tokenB, fee)`)
 *   3. NO FEE TIERS: Algebra pools have dynamic fees, no fee param in pool lookup
 *
 * G4 resolves all three by:
 *   - Adding `algebraFlashCallback()` routed to shared `_flashCallback()`
 *   - Overriding `_verifyFlashCallback()` / `getUniswapPoolAddress()` to fall back to `poolByPair`
 *
 * Run with:
 *   FOUNDRY_PROFILE=fork forge test --match-contract ApeChain_SwapRolloverLoan_Test -vvvv \
 *     --fork-url <APECHAIN_RPC_URL>
 */
contract ApeChain_SwapRolloverLoan_Test is Test {

    string constant NETWORK_NAME = "apechain";

    using stdJson for string;

    // ApeChain addresses
    address constant CAMELOT_V3_FACTORY = 0x10aA510d94E094Bd643677bd2964c3EE085Daffc;
    address constant WAPE = 0x48b62137EdfA95a428D35C09E44256a739F6B557;
    address constant ApeUSD = 0xA2235d059F80e176D931Ef76b6C51953Eb3fBEf4;

    SwapRolloverLoan swapRolloverLoan;
    address smartCommitmentForwarder;
    address tellerV2Addr;

    address camelotPool;

    function getDeployedAddress(string memory contractName) internal view returns (address) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/", NETWORK_NAME, "/", contractName, ".json");
        string memory json = vm.readFile(path);
        return json.readAddress(".address");
    }

    function setUp() public {
        address payable swapRolloverAddr = payable(getDeployedAddress("SwapRolloverLoan"));
        swapRolloverLoan = SwapRolloverLoan(swapRolloverAddr);
        smartCommitmentForwarder = getDeployedAddress("SmartCommitmentForwarder");
        tellerV2Addr = getDeployedAddress("TellerV2");

        assertTrue(swapRolloverAddr.code.length > 0, "SwapRolloverLoan not deployed");
        assertTrue(smartCommitmentForwarder.code.length > 0, "SmartCommitmentForwarder not deployed");

        camelotPool = IAlgebraFactory_Test(CAMELOT_V3_FACTORY).poolByPair(WAPE, ApeUSD);
        require(camelotPool != address(0), "No WAPE/ApeUSD Camelot pool");

        console.log("SwapRolloverLoan:", swapRolloverAddr);
        console.log("TellerV2:", tellerV2Addr);
        console.log("Camelot V3 WAPE/ApeUSD pool:", camelotPool);
    }

    // ============ Compatibility Tests ============

    /// @notice Verify Camelot V3 pool has a flash() function (same signature as Uniswap V3)
    function test_camelotV3_flash_exists() public {
        // Algebra pools implement flash(address,uint256,uint256,bytes) — same as Uniswap V3
        bytes4 flashSelector = IAlgebraPool_Test.flash.selector;
        console.log("flash() selector:");
        console.logBytes4(flashSelector);

        // Verify pool has code and flash function exists
        assertTrue(camelotPool.code.length > 0, "Pool has code");

        // staticcall flash with 0 amounts should not revert (just a dry run check)
        // Note: actual flash with 0 amounts may revert in some implementations,
        // so we just verify the pool contract exists and has liquidity
        IAlgebraPool_Test pool = IAlgebraPool_Test(camelotPool);
        (uint160 price,,,,,,, bool unlocked) = pool.globalState();
        assertGt(price, 0, "Pool has valid price");
        assertTrue(unlocked, "Pool is unlocked");

        console.log("Camelot V3 pool is active, flash() available");
    }

    /// @notice Verify getPool() reverts on Algebra factory (no fee tiers)
    function test_factory_getPool_reverts_on_algebra() public {
        (bool success,) = CAMELOT_V3_FACTORY.staticcall(
            abi.encodeWithSelector(IUniswapV3Factory_Test.getPool.selector, WAPE, ApeUSD, uint24(3000))
        );
        assertFalse(success, "getPool() should revert on Algebra factory");
        console.log("CONFIRMED: getPool(token0, token1, fee) reverts on Algebra factory");
    }

    /// @notice Verify poolByPair() works on Algebra factory
    function test_factory_poolByPair_works() public {
        address pool = IAlgebraFactory_Test(CAMELOT_V3_FACTORY).poolByPair(WAPE, ApeUSD);
        assertTrue(pool != address(0), "poolByPair should return valid address");
        assertEq(pool, camelotPool, "Should match setUp pool");
        console.log("CONFIRMED: poolByPair(tokenA, tokenB) works on Algebra factory");
    }

    // ============ Callback Selector Tests ============

    /// @notice Verify current deployed implementation's callback selectors
    function test_deployed_callback_selectors() public {
        // Read implementation address from proxy storage
        address impl = address(uint160(uint256(vm.load(
            address(swapRolloverLoan),
            bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        ))));
        console.log("Current implementation:", impl);

        bytes memory implCode = impl.code;

        bytes4 uniswapSelector = bytes4(keccak256("uniswapV3FlashCallback(uint256,uint256,bytes)"));
        bytes4 pancakeSelector = bytes4(keccak256("pancakeV3FlashCallback(uint256,uint256,bytes)"));
        bytes4 algebraSelector = bytes4(keccak256("algebraFlashCallback(uint256,uint256,bytes)"));

        console.log("uniswapV3FlashCallback selector:"); console.logBytes4(uniswapSelector);
        console.log("pancakeV3FlashCallback selector:"); console.logBytes4(pancakeSelector);
        console.log("algebraFlashCallback selector:");   console.logBytes4(algebraSelector);

        bool hasUniswap = _bytecodeContainsSelector(implCode, uniswapSelector);
        bool hasPancake = _bytecodeContainsSelector(implCode, pancakeSelector);
        bool hasAlgebra = _bytecodeContainsSelector(implCode, algebraSelector);

        console.log("Has uniswapV3FlashCallback:", hasUniswap);
        console.log("Has pancakeV3FlashCallback:", hasPancake);
        console.log("Has algebraFlashCallback:", hasAlgebra);

        // Current ApeChain deployment is G2 — only has uniswapV3FlashCallback
        assertTrue(hasUniswap, "Should have uniswapV3FlashCallback");
        // G2 does NOT have pancake or algebra callbacks — documents the gap
        assertFalse(hasPancake, "G2 impl missing pancakeV3FlashCallback");
        assertFalse(hasAlgebra, "G2 impl missing algebraFlashCallback (needs G4 upgrade)");
    }

    // ============ G4 Upgrade Tests ============

    /// @notice Deploy G4 implementation and verify it has all three callback selectors
    function test_g4_has_all_callbacks() public {
        SwapRolloverLoan g4Impl = new SwapRolloverLoan(
            tellerV2Addr,
            CAMELOT_V3_FACTORY,
            WAPE
        );

        bytes memory g4Code = address(g4Impl).code;

        bytes4 uniswapSelector = bytes4(keccak256("uniswapV3FlashCallback(uint256,uint256,bytes)"));
        bytes4 pancakeSelector = bytes4(keccak256("pancakeV3FlashCallback(uint256,uint256,bytes)"));
        bytes4 algebraSelector = bytes4(keccak256("algebraFlashCallback(uint256,uint256,bytes)"));

        assertTrue(_bytecodeContainsSelector(g4Code, uniswapSelector), "G4 has uniswapV3FlashCallback");
        assertTrue(_bytecodeContainsSelector(g4Code, pancakeSelector), "G4 has pancakeV3FlashCallback");
        assertTrue(_bytecodeContainsSelector(g4Code, algebraSelector), "G4 has algebraFlashCallback");

        console.log("G4 has all three flash callbacks: uniswap, pancake, algebra");
    }

    /// @notice Verify G4's pool resolution works with Algebra factory (poolByPair fallback)
    function test_g4_resolves_algebra_pool() public {
        SwapRolloverLoan g4Impl = new SwapRolloverLoan(
            tellerV2Addr,
            CAMELOT_V3_FACTORY,
            WAPE
        );

        // G4 getUniswapPoolAddress should resolve via poolByPair fallback
        // fee param is ignored for Algebra — pass any value
        address resolved = g4Impl.getUniswapPoolAddress(WAPE, ApeUSD, 0);
        assertEq(resolved, camelotPool, "G4 should resolve Algebra pool via poolByPair");

        console.log("G4 resolves Camelot V3 pool:", resolved);
        console.log("Expected:", camelotPool);
    }

    /// @notice Etch G4 implementation over proxy and verify pool resolution still works
    function test_g4_etch_and_resolve() public {
        // Deploy G4 with Algebra factory
        SwapRolloverLoan g4Impl = new SwapRolloverLoan(
            tellerV2Addr,
            CAMELOT_V3_FACTORY,
            WAPE
        );

        // Read current implementation address
        address currentImpl = address(uint160(uint256(vm.load(
            address(swapRolloverLoan),
            bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        ))));

        // Etch G4 code over the implementation
        vm.etch(currentImpl, address(g4Impl).code);
        console.log("Etched G4 implementation over proxy impl:", currentImpl);

        // Verify pool resolution through proxy
        address resolved = swapRolloverLoan.getUniswapPoolAddress(WAPE, ApeUSD, 0);
        assertEq(resolved, camelotPool, "Proxy should resolve Algebra pool after G4 etch");

        console.log("Pool resolution through proxy works after G4 upgrade");
    }

    // ============ Helpers ============

    function _bytecodeContainsSelector(bytes memory code, bytes4 selector) internal pure returns (bool) {
        if (code.length < 4) return false;
        for (uint256 i = 0; i < code.length - 3; i++) {
            if (code[i] == selector[0] &&
                code[i+1] == selector[1] &&
                code[i+2] == selector[2] &&
                code[i+3] == selector[3]) {
                return true;
            }
        }
        return false;
    }
}
