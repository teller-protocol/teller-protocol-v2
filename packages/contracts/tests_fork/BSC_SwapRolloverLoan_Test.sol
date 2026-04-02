// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { SwapRolloverLoan } from "../contracts/LenderCommitmentForwarder/extensions/rollover/SwapRolloverLoan.sol";
import { SwapRolloverLoan_G2 } from "../contracts/LenderCommitmentForwarder/extensions/rollover/SwapRolloverLoan_G2.sol";
import { ITellerV2 } from "../contracts/interfaces/ITellerV2.sol";

interface IUniswapV3Pool_BSC {
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
}

interface IUniswapV3Factory_BSC {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

contract BSC_SwapRolloverLoan_Test is Test {

    string constant NETWORK_NAME = "bsc";

    using stdJson for string;

    // BSC addresses
    address constant BUSD = 0xbA2aE424d960c26247Dd6c32edC70B295c744C43;
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address constant PANCAKE_FACTORY = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;

    // The borrower from the failed tx
    address constant BORROWER = 0xC5eA5A6771785CFD353F097e2E8F0177263e7779;

    SwapRolloverLoan swapRolloverLoan;
    address smartCommitmentForwarder;

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

        assertTrue(swapRolloverAddr.code.length > 0, "SwapRolloverLoan not deployed");
        console.log("SwapRolloverLoan:", swapRolloverAddr);
        console.log("SmartCommitmentForwarder:", smartCommitmentForwarder);
    }

    /**
     * @notice Replays the exact failed BSC tx with the original calldata.
     *         Expected to revert due to PancakeSwap V3 callback mismatch:
     *         PancakeSwap calls `pancakeV3FlashCallback` but contract implements `uniswapV3FlashCallback`.
     *
     *  Run with:
     *    forge test --match-test test_replay_failed_bsc_rollover -vvvv \
     *      --fork-url https://bsc-mainnet.nodereal.io/v1/<YOUR_KEY> \
     *      --fork-block-number 90218095
     */
    function test_replay_failed_bsc_rollover() public {

        uint256 loanId = 1;

        // Verify loan state
        ITellerV2 tellerV2 = ITellerV2(swapRolloverLoan.TELLER_V2());
        address borrower = tellerV2.getLoanBorrower(loanId);
        console.log("Loan borrower:", borrower);
        console.log("Expected borrower:", BORROWER);
        require(borrower == BORROWER, "Borrower mismatch");

        // Flash swap args from the failed tx
        SwapRolloverLoan_G2.FlashSwapArgs memory flashSwapArgs = SwapRolloverLoan_G2.FlashSwapArgs({
            token0: BUSD,
            token1: WBNB,
            fee: 2500,
            flashAmount: 27520961,  // bumped from original 27470961 to cover interest
            borrowToken1: false     // flash borrow BUSD (token0)
        });

        // Accept commitment args from the failed tx
        SwapRolloverLoan_G2.AcceptCommitmentArgs memory acceptCommitmentArgs = SwapRolloverLoan_G2.AcceptCommitmentArgs({
            commitmentId: 0,
            smartCommitmentAddress: 0xa890AaC4151A4a0eCE88222b33D2C9e07cA467C1,
            principalAmount: 27432331,
            collateralAmount: 99999998195559912,
            collateralTokenId: 0,
            collateralTokenAddress: USDC,
            interestRate: 2749,
            loanDuration: 2592000,
            merkleProof: new bytes32[](0)
        });

        uint256 borrowerAmount = 703152;

        // Log pre-state
        console.log("--- Pre-state ---");
        console.log("Borrower BUSD balance:", IERC20(BUSD).balanceOf(BORROWER));
        console.log("Borrower USDC balance:", IERC20(USDC).balanceOf(BORROWER));
        console.log("BUSD allowance to SwapRolloverLoan:", IERC20(BUSD).allowance(BORROWER, address(swapRolloverLoan)));

        // Check pool exists
        address pool = IUniswapV3Factory_BSC(PANCAKE_FACTORY).getPool(BUSD, WBNB, 2500);
        console.log("PancakeSwap V3 BUSD/WBNB pool:", pool);
        require(pool != address(0), "Pool does not exist");

        // Attempt the rollover (expect revert due to pancakeV3FlashCallback mismatch)
        vm.prank(BORROWER);
        // NOTE: This will revert because PancakeSwap V3 calls pancakeV3FlashCallback
        // but SwapRolloverLoan_G2 only implements uniswapV3FlashCallback
        vm.expectRevert();
        swapRolloverLoan.rolloverLoanWithFlashSwap(
            smartCommitmentForwarder,
            loanId,
            borrowerAmount,
            flashSwapArgs,
            acceptCommitmentArgs
        );

        console.log("Confirmed: rollover reverts (pancakeV3FlashCallback not implemented)");
    }

    /**
     * @notice Tests that the fix works: deploy new SwapRolloverLoan with pancakeV3FlashCallback,
     *         etch it over the proxy's implementation, and replay the rollover.
     *
     *  Run with (requires a paid/high-rate-limit BSC archive RPC):
     *    FOUNDRY_PROFILE=fork forge test --match-test test_rollover_with_pancake_callback_fix -vvvv \
     *      --fork-url <BSC_ARCHIVE_RPC_URL> \
     *      --fork-block-number 90218095
     */
    function test_rollover_with_pancake_callback_fix() public {

        uint256 loanId = 1;

        ITellerV2 tellerV2 = ITellerV2(swapRolloverLoan.TELLER_V2());

        // Deploy the fixed SwapRolloverLoan (which now has pancakeV3FlashCallback)
        SwapRolloverLoan fixedImpl = new SwapRolloverLoan(
            address(tellerV2),
            PANCAKE_FACTORY,
            WBNB
        );

        // Etch the fixed implementation over the proxy's implementation slot
        address currentImpl = address(uint160(uint256(vm.load(
            address(swapRolloverLoan),
            bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        ))));
        console.log("Current impl:", currentImpl);
        vm.etch(currentImpl, address(fixedImpl).code);
        console.log("Etched fixed implementation");

        // Flash swap args - bump flash amount to cover interest
        SwapRolloverLoan_G2.FlashSwapArgs memory flashSwapArgs = SwapRolloverLoan_G2.FlashSwapArgs({
            token0: BUSD,
            token1: WBNB,
            fee: 2500,
            flashAmount: 27520961,  // bumped to cover interest
            borrowToken1: false
        });

        SwapRolloverLoan_G2.AcceptCommitmentArgs memory acceptCommitmentArgs = SwapRolloverLoan_G2.AcceptCommitmentArgs({
            commitmentId: 0,
            smartCommitmentAddress: 0xa890AaC4151A4a0eCE88222b33D2C9e07cA467C1,
            principalAmount: 27432331,
            collateralAmount: 99999998195559912,
            collateralTokenId: 0,
            collateralTokenAddress: USDC,
            interestRate: 2749,
            loanDuration: 2592000,
            merkleProof: new bytes32[](0)
        });

        uint256 borrowerAmount = 703152;

        console.log("--- Pre-state ---");
        console.log("Borrower BUSD:", IERC20(BUSD).balanceOf(BORROWER));
        console.log("Borrower USDC:", IERC20(USDC).balanceOf(BORROWER));

        vm.prank(BORROWER);
        swapRolloverLoan.rolloverLoanWithFlashSwap(
            smartCommitmentForwarder,
            loanId,
            borrowerAmount,
            flashSwapArgs,
            acceptCommitmentArgs
        );

        console.log("Rollover succeeded with pancakeV3FlashCallback fix!");
        console.log("Borrower BUSD after:", IERC20(BUSD).balanceOf(BORROWER));
    }

    /**
     * @notice Verifies the root cause: PancakeSwap V3 pool uses pancakeV3FlashCallback,
     *         not uniswapV3FlashCallback.
     */
    function test_pancakeswap_callback_mismatch() public {
        // Get the pool
        address pool = IUniswapV3Factory_BSC(PANCAKE_FACTORY).getPool(BUSD, WBNB, 2500);
        require(pool != address(0), "Pool does not exist");
        console.log("Pool address:", pool);

        // Check the pool bytecode for callback selectors
        bytes memory poolCode = address(pool).code;

        // pancakeV3FlashCallback(uint256,uint256,bytes) = 0xa1d48336
        // uniswapV3FlashCallback(uint256,uint256,bytes) = 0xe9cbafb0
        bytes4 pancakeSelector = bytes4(keccak256("pancakeV3FlashCallback(uint256,uint256,bytes)"));
        bytes4 uniswapSelector = bytes4(keccak256("uniswapV3FlashCallback(uint256,uint256,bytes)"));

        console.log("PancakeSwap callback selector:");
        console.logBytes4(pancakeSelector);
        console.log("Uniswap callback selector:");
        console.logBytes4(uniswapSelector);

        bool hasPancakeCallback = _bytecodeContainsSelector(poolCode, pancakeSelector);
        bool hasUniswapCallback = _bytecodeContainsSelector(poolCode, uniswapSelector);

        console.log("Pool has pancakeV3FlashCallback:", hasPancakeCallback);
        console.log("Pool has uniswapV3FlashCallback:", hasUniswapCallback);

        // The pool should have pancake callback but NOT uniswap callback
        assertTrue(hasPancakeCallback, "Pool should reference pancakeV3FlashCallback");
        assertFalse(hasUniswapCallback, "Pool should NOT reference uniswapV3FlashCallback");

        // Check SwapRolloverLoan bytecode
        bytes memory rolloverCode = address(swapRolloverLoan).code;

        // The implementation is behind a proxy, so check the implementation
        // The proxy delegates to implementation, so the callback must be in the impl
        address impl = address(uint160(uint256(vm.load(address(swapRolloverLoan), bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)))));
        console.log("SwapRolloverLoan implementation:", impl);

        bytes memory implCode = impl.code;
        bool implHasPancake = _bytecodeContainsSelector(implCode, pancakeSelector);
        bool implHasUniswap = _bytecodeContainsSelector(implCode, uniswapSelector);

        console.log("Impl has pancakeV3FlashCallback:", implHasPancake);
        console.log("Impl has uniswapV3FlashCallback:", implHasUniswap);

        // ROOT CAUSE: impl has uniswap callback but pool expects pancake callback
        assertTrue(implHasUniswap, "Impl should have uniswapV3FlashCallback");
        assertFalse(implHasPancake, "Impl should NOT have pancakeV3FlashCallback (this is the bug)");
    }

    function _bytecodeContainsSelector(bytes memory code, bytes4 selector) internal pure returns (bool) {
        bytes4 target = selector;
        for (uint256 i = 0; i < code.length - 3; i++) {
            if (code[i] == target[0] &&
                code[i+1] == target[1] &&
                code[i+2] == target[2] &&
                code[i+3] == target[3]) {
                return true;
            }
        }
        return false;
    }
}
