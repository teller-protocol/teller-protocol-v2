// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";

/*
    Defensive fork test for the attack attempted by

        EOA      : 0x0951d0c55e5e110bde899af6c555cb1dbb9be175
        Contract : 0x40e99f02f0b4670fb3205ab9c708af8609c5ddd5  (deployed in
                   tx 0x63b54c56aabbfffee400cdc13d95ac0478ca88f841666deb6cd263a7b78dcf8e)

    What that attacker contract attempted:

      1. Receive a WETH "flash loan" via a Morpho Blue callback.
      2. Swap WETH -> KTA on the Uniswap V3 WETH/KTA 1% fee pool.
      3. Query the Teller USDC-KTA LenderCommitmentGroup pool for the collateral
         required to borrow the available USDC, via
             calculateCollateralRequiredToBorrowPrincipal(principal)
      4. If the KTA balance obtained from step 2 covers the required collateral,
         call SmartCommitmentForwarder.acceptSmartCommitmentWithRecipient(...)
         to borrow USDC against KTA.
      5. Swap the borrowed USDC back to WETH.
      6. Hand the WETH back to Morpho (flash loan repayment).

    The implicit assumption behind the attack is that pumping the WETH/KTA
    price inside the same transaction would either (a) inflate the oracle
    price used by the Teller pool so that a very small amount of KTA can
    borrow a very large amount of USDC, or (b) otherwise produce a net
    WETH/USDC profit that pays the flash loan and leaves a surplus.

    Two independent defenses in the Teller protocol stop this:

        (A) The Teller pool's price oracle uses a Uniswap V3 TWAP with
            twapInterval > 0. The TWAP window is written from observations
            committed in *past* blocks; a same-tx spot-price move does not
            change the TWAP read.

        (B) SmartCommitmentForwarder.acceptSmartCommitmentWithRecipient is
            gated by onlyOracleApprovedAllowEOA (the Hypernative oracle).
            A freshly-deployed, unregistered smart contract that is not the
            tx.origin will be rejected with "Oracle: Not Approved" / "O_NA"
            when Hypernative is active.

    This test asserts both defenses against the *live* USDC-KTA
    LenderCommitmentGroup pool at 0xecd32cacd1178a118b9fac2b5a43c52f010cf4ea
    on Base, and then replays the full attack flow and proves it either
    reverts or is strictly unprofitable.

    Run with:
        FOUNDRY_PROFILE=defensive forge test \
            --fork-url $BASE_RPC_URL \
            -vv
*/

// ---------- Minimal interfaces (no protocol imports, keep compile scope small) ----------

interface IERC20Like {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

interface IUniswapV3PoolLike {
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

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24  fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(ExactInputSingleParams calldata params)
        external payable returns (uint256 amountOut);
}

// UsdcKta pool is a V2 pool (has poolOracleRoutes, UNISWAP_PRICING_HELPER),
// it does NOT expose priceAdapter()/priceRouteHash(), so we use the V2 surface.
interface ILenderCommitmentGroupPoolV2Like {
    struct PoolRouteConfig {
        address pool;
        bool    zeroForOne;
        uint32  twapInterval;
        uint256 token0Decimals;
        uint256 token1Decimals;
    }

    function principalToken() external view returns (address);
    function collateralToken() external view returns (address);
    function collateralRatio() external view returns (uint16);
    function maxLoanDuration() external view returns (uint32);
    function interestRateLowerBound() external view returns (uint16);
    function interestRateUpperBound() external view returns (uint16);
    function poolOracleRoutes(uint256) external view returns (
        address pool,
        bool    zeroForOne,
        uint32  twapInterval,
        uint256 token0Decimals,
        uint256 token1Decimals
    );
    function UNISWAP_PRICING_HELPER() external view returns (address);
    function getPrincipalAmountAvailableToBorrow() external view returns (uint256);
    function calculateCollateralRequiredToBorrowPrincipal(uint256) external view returns (uint256);
}

interface IUniswapPricingHelperLike {
    struct PoolRouteConfig {
        address pool;
        bool    zeroForOne;
        uint32  twapInterval;
        uint256 token0Decimals;
        uint256 token1Decimals;
    }
    function getUniswapPriceRatioForPoolRoutes(PoolRouteConfig[] memory)
        external view returns (uint256);
}

interface ISmartCommitmentForwarderLike {
    function acceptSmartCommitmentWithRecipient(
        address _smartCommitmentAddress,
        uint256 _principalAmount,
        uint256 _collateralAmount,
        uint256 _collateralTokenId,
        address _collateralTokenAddress,
        address _recipient,
        uint16  _interestRate,
        uint32  _loanDuration
    ) external returns (uint256 bidId);
}


// ---------- Attacker replay contract (mirror of the real attacker bytecode) ----------

contract AttackerReplay {
    address public immutable WETH;
    address public immutable KTA;
    address public immutable USDC;
    address public immutable SWAP_ROUTER;
    address public immutable SCF;
    address public immutable POOL;

    constructor(
        address _weth,
        address _kta,
        address _usdc,
        address _router,
        address _scf,
        address _pool
    ) {
        WETH = _weth;
        KTA  = _kta;
        USDC = _usdc;
        SWAP_ROUTER = _router;
        SCF  = _scf;
        POOL = _pool;
    }

    /// @notice Runs the full attack flow.
    /// @param wethIn The amount of WETH already sitting on this contract that
    ///               we pretend was flash-borrowed.
    /// @return finalWeth   Final WETH balance (pre-any flash-loan repayment).
    function runAttack(uint256 wethIn) external returns (uint256 finalWeth) {
        // --- Step 1: swap WETH -> KTA at the 1% fee tier ---
        IERC20Like(WETH).approve(SWAP_ROUTER, wethIn);

        ISwapRouter02.ExactInputSingleParams memory p = ISwapRouter02.ExactInputSingleParams({
            tokenIn:           WETH,
            tokenOut:          KTA,
            fee:               10000,
            recipient:         address(this),
            amountIn:          wethIn,
            amountOutMinimum:  0,
            sqrtPriceLimitX96: 0
        });
        ISwapRouter02(SWAP_ROUTER).exactInputSingle(p);

        // --- Step 2: read oracle-priced collateral requirement ---
        uint256 available = ILenderCommitmentGroupPoolV2Like(POOL)
            .getPrincipalAmountAvailableToBorrow();
        uint256 required  = ILenderCommitmentGroupPoolV2Like(POOL)
            .calculateCollateralRequiredToBorrowPrincipal(available);

        uint256 ktaBal = IERC20Like(KTA).balanceOf(address(this));

        // --- Step 3: attempt the borrow (this is where onlyOracleApprovedAllowEOA lives) ---
        if (ktaBal >= required && available > 0) {
            IERC20Like(KTA).approve(SCF, required);

            ISmartCommitmentForwarderLike(SCF).acceptSmartCommitmentWithRecipient(
                POOL,
                available,
                required,
                0,
                KTA,
                address(this),
                2600,    // interestRate (bps)
                8650000  // loanDuration
            );

            // --- Step 4: swap the received USDC back to WETH ---
            uint256 usdcBal = IERC20Like(USDC).balanceOf(address(this));
            if (usdcBal > 0) {
                IERC20Like(USDC).approve(SWAP_ROUTER, usdcBal);
                ISwapRouter02.ExactInputSingleParams memory p2 = ISwapRouter02.ExactInputSingleParams({
                    tokenIn:           USDC,
                    tokenOut:          WETH,
                    fee:               500,
                    recipient:         address(this),
                    amountIn:          usdcBal,
                    amountOutMinimum:  0,
                    sqrtPriceLimitX96: 0
                });
                ISwapRouter02(SWAP_ROUTER).exactInputSingle(p2);
            }
        }

        // --- Step 5: also sweep any leftover KTA back to WETH (what the real attacker did) ---
        uint256 leftoverKta = IERC20Like(KTA).balanceOf(address(this));
        if (leftoverKta > 0) {
            IERC20Like(KTA).approve(SWAP_ROUTER, leftoverKta);
            ISwapRouter02.ExactInputSingleParams memory p3 = ISwapRouter02.ExactInputSingleParams({
                tokenIn:           KTA,
                tokenOut:          WETH,
                fee:               10000,
                recipient:         address(this),
                amountIn:          leftoverKta,
                amountOutMinimum:  0,
                sqrtPriceLimitX96: 0
            });
            ISwapRouter02(SWAP_ROUTER).exactInputSingle(p3);
        }

        finalWeth = IERC20Like(WETH).balanceOf(address(this));
    }
}


// ---------- The test ----------

contract Attack_UsdcKta_PriceManipulation_Fork_Test is Test {

    // Tokens on Base
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant KTA  = 0xc0634090F2Fe6c6d75e61Be2b949464aBB498973;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    // Uniswap V3 infra on Base
    address constant UNIV3_SWAP_ROUTER_02 = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address constant UNIV3_WETH_KTA_1PCT  = 0x8d421B0D641193D67Dd1aa024DAb17fcdE0BfC89;

    // Teller live infra on Base
    address constant SCF  = 0x0708480670BdE591e275B06Cd19EcaDFC93A1f16; // SmartCommitmentForwarder
    address constant POOL = 0xecd32CACD1178a118B9Fac2b5A43C52F010cF4ea; // USDC-KTA LenderCommitmentGroup pool

    // The real attacker's identities (from on-chain)
    address constant ATTACKER_EOA      = 0x0951d0c55e5E110bde899AF6c555Cb1DbB9BE175;
    address constant ATTACKER_CONTRACT = 0x40E99f02F0b4670FB3205aB9c708aF8609C5Ddd5;

    AttackerReplay internal attacker;

    function setUp() public {
        // We expect the runner to have passed --fork-url for Base mainnet.
        require(block.chainid == 8453, "Must be forked on Base (chainId 8453)");

        attacker = new AttackerReplay(
            WETH, KTA, USDC, UNIV3_SWAP_ROUTER_02, SCF, POOL
        );

        console.log("Forked Base at block:", block.number);
        console.log("Attacker replay deployed at:", address(attacker));
    }

    // -----------------------------------------------------------------
    // Defense (A): verify the live pool uses a non-zero TWAP interval
    // -----------------------------------------------------------------

    function test_A_pool_uses_twap_oracle() public {
        ILenderCommitmentGroupPoolV2Like pool = ILenderCommitmentGroupPoolV2Like(POOL);

        // Sanity-check the live pool is what we think it is.
        assertEq(pool.principalToken(),  USDC, "principal token mismatch");
        assertEq(pool.collateralToken(), KTA,  "collateral token mismatch");

        (
            address poolAddr,
            bool    zeroForOne,
            uint32  twapInterval,
            ,
        ) = pool.poolOracleRoutes(0);

        console.log("oracle pool:", poolAddr);
        console.log("zeroForOne :", zeroForOne);
        console.log("twapInterval(s):", uint256(twapInterval));

        // The pool MUST be the WETH/KTA pool we expect
        assertEq(poolAddr, UNIV3_WETH_KTA_1PCT, "oracle pool is not the expected WETH/KTA pool");

        // TWAP MUST be strictly greater than 0; a spot-price oracle (=0) would
        // make the pool vulnerable to the single-tx manipulation in the attack.
        // Even a 1-second TWAP is enough to defeat same-tx manipulation because
        // the observation it consults was already committed in a prior block.
        assertGt(uint256(twapInterval), 0, "Defense broken: pool uses SPOT price!");
    }

    // -----------------------------------------------------------------
    // Defense (A), part 2:
    // A massive same-tx swap on the underlying UniV3 pool does NOT move
    // the TWAP price the Teller pool reads.
    // -----------------------------------------------------------------

    function test_B_twap_not_moved_by_sametx_swap() public {
        ILenderCommitmentGroupPoolV2Like pool = ILenderCommitmentGroupPoolV2Like(POOL);
        address helper = pool.UNISWAP_PRICING_HELPER();

        // Rebuild the pool's route config from storage.
        (
            address oPool,
            bool    zeroForOne,
            uint32  twapInterval,
            uint256 t0Dec,
            uint256 t1Dec
        ) = pool.poolOracleRoutes(0);

        IUniswapPricingHelperLike.PoolRouteConfig[] memory routes =
            new IUniswapPricingHelperLike.PoolRouteConfig[](1);
        routes[0] = IUniswapPricingHelperLike.PoolRouteConfig({
            pool:           oPool,
            zeroForOne:     zeroForOne,
            twapInterval:   twapInterval,
            token0Decimals: t0Dec,
            token1Decimals: t1Dec
        });

        uint256 priceBefore = IUniswapPricingHelperLike(helper)
            .getUniswapPriceRatioForPoolRoutes(routes);

        // Also record the spot tick just to show it moves vs TWAP doesn't.
        (uint160 sqrtBefore, int24 tickBefore,,,,,) = IUniswapV3PoolLike(UNIV3_WETH_KTA_1PCT).slot0();

        // Give the test contract a large pile of WETH and slam the pool.
        // deal() is Foundry's cheatcode that adjusts balances on a fork.
        uint256 bigWeth = 2000 ether;
        deal(WETH, address(this), bigWeth);
        IERC20Like(WETH).approve(UNIV3_SWAP_ROUTER_02, bigWeth);

        ISwapRouter02.ExactInputSingleParams memory p = ISwapRouter02.ExactInputSingleParams({
            tokenIn:           WETH,
            tokenOut:          KTA,
            fee:               10000,
            recipient:         address(this),
            amountIn:          bigWeth,
            amountOutMinimum:  0,
            sqrtPriceLimitX96: 0
        });
        ISwapRouter02(UNIV3_SWAP_ROUTER_02).exactInputSingle(p);

        (uint160 sqrtAfter, int24 tickAfter,,,,,) = IUniswapV3PoolLike(UNIV3_WETH_KTA_1PCT).slot0();

        uint256 priceAfter = IUniswapPricingHelperLike(helper)
            .getUniswapPriceRatioForPoolRoutes(routes);

        console.log("spot sqrtPriceX96 before :", uint256(sqrtBefore));
        console.log("spot sqrtPriceX96 after  :", uint256(sqrtAfter));
        console.logInt(int256(tickBefore));
        console.logInt(int256(tickAfter));
        console.log("TWAP priceRatioQ96 before:", priceBefore);
        console.log("TWAP priceRatioQ96 after :", priceAfter);

        // The spot MUST have moved (sanity-check the swap actually happened).
        assertTrue(sqrtBefore != sqrtAfter, "sanity: spot should move after a big swap");

        // The TWAP read MUST be identical: single-tx manipulation cannot alter it
        // because the observations used by the TWAP were committed in prior blocks.
        assertEq(priceAfter, priceBefore, "Defense broken: TWAP moved within a single tx!");
    }

    // -----------------------------------------------------------------
    // Defense (B): replay the full attack flow from a non-EOA context
    // and show the borrow step reverts (Hypernative oracle blocks it).
    // -----------------------------------------------------------------

    function test_C_attack_reverts_from_smart_contract() public {
        // Fund the attacker replay the same way the real attacker did (flash loan => WETH on the contract).
        uint256 flashAmount = 500 ether; // generous - way more than the real attacker used
        deal(WETH, address(attacker), flashAmount);

        // Call from a random EOA as tx.origin but msg.sender on SCF will be
        // the replay contract (exactly like the real attacker deployed contract).
        vm.prank(ATTACKER_EOA, ATTACKER_EOA);

        // We don't know whether Hypernative on Base is currently "strict";
        // either outcome is acceptable:
        //   - It reverts with "O_NA" / "Oracle: Not Approved" (defense active)
        //   - OR it passes the gate but the attack still has to be proven unprofitable,
        //     which the next test (test_D) covers.
        try attacker.runAttack(flashAmount) returns (uint256 finalWeth) {
            console.log("runAttack did not revert; final WETH:", finalWeth);
            // If we got here, the Hypernative gate was open. The attack must then
            // be unprofitable (i.e. finalWeth <= flashAmount) or the defense is broken.
            assertLe(
                finalWeth,
                flashAmount,
                "Defense broken: attack produced a net profit!"
            );
        } catch Error(string memory reason) {
            console.log("runAttack reverted with:", reason);
            // Expected: "O_NA" or "Oracle: Not Approved" from the Hypernative gate.
            // Any revert here means the attack path was refused - defense active.
            assertTrue(bytes(reason).length > 0, "unexpected empty revert");
        } catch (bytes memory data) {
            console.log("runAttack reverted with raw data length:", data.length);
            assertTrue(data.length > 0, "unexpected empty revert");
        }
    }

    // -----------------------------------------------------------------
    // Defense (A+B), combined, worst case: bypass the Hypernative gate and
    // show the attack is still strictly unprofitable because the TWAP oracle
    // doesn't move. This is the "what if the attacker registered" case.
    // -----------------------------------------------------------------

    function test_D_attack_unprofitable_even_if_oracle_gate_bypassed() public {
        // Neutralize the Hypernative gate on the forwarder by deleting the
        // oracle address from its storage slot. This is the "worst case":
        // assume the attacker somehow got past the gate.
        //
        // The slot used by OracleProtectionManager is:
        //   bytes32(uint256(keccak256("eip1967.hypernative.oracle")) - 1)
        bytes32 slot = bytes32(uint256(keccak256("eip1967.hypernative.oracle")) - 1);
        vm.store(SCF, slot, bytes32(0));

        // Sanity-check we zeroed it.
        bytes32 stored = vm.load(SCF, slot);
        assertEq(stored, bytes32(0), "failed to zero hypernative oracle slot");

        uint256 flashAmount = 500 ether;
        deal(WETH, address(attacker), flashAmount);

        uint256 wethBefore = IERC20Like(WETH).balanceOf(address(attacker));

        // Run - this call may still revert for other reasons (e.g. pool
        // paused, whenBorrowingNotPaused, etc). Any revert is also a pass
        // because the attacker cannot extract value.
        try attacker.runAttack(flashAmount) returns (uint256 finalWeth) {
            console.log("bypassed-gate attack completed; final WETH:", finalWeth);
            console.log("flash amount (must repay)                 :", flashAmount);

            // The critical assertion: the attacker ends up with STRICTLY LESS
            // WETH than they started with. In other words, they can never repay
            // a flash loan and pocket profit using this path.
            assertLt(
                finalWeth,
                wethBefore,
                "Defense broken: attacker ended with at least as much WETH as they started"
            );
        } catch Error(string memory reason) {
            console.log("bypassed-gate attack reverted:", reason);
            // Reverts are a pass; the attack doesn't work.
        } catch (bytes memory) {
            console.log("bypassed-gate attack reverted (no string)");
        }
    }
}
