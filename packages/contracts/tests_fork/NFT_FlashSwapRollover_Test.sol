// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "../tests/util/FoundryTest.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { SwapRolloverLoan } from "../contracts/LenderCommitmentForwarder/extensions/rollover/SwapRolloverLoan.sol";
import { SwapRolloverLoan_G2 } from "../contracts/LenderCommitmentForwarder/extensions/rollover/SwapRolloverLoan_G2.sol";
import { ITellerV2 } from "../contracts/interfaces/ITellerV2.sol";
import { Payment } from "../contracts/TellerV2Storage.sol";

interface ILenderCommitmentForwarder_Debug {
    // Matches LenderCommitmentForwarder_G1.Commitment storage layout exactly
    struct Commitment {
        uint256 maxPrincipal;
        uint32 expiration;
        uint32 maxDuration;
        uint16 minInterestRate;
        address collateralTokenAddress;
        uint256 collateralTokenId;
        uint256 maxPrincipalPerCollateralAmount;
        uint8 collateralTokenType; // CommitmentCollateralType enum
        address lender;
        uint256 marketId;
        address principalTokenAddress;
    }

    function commitments(uint256 _commitmentId) external view returns (
        uint256 maxPrincipal,
        uint32 expiration,
        uint32 maxDuration,
        uint16 minInterestRate,
        address collateralTokenAddress,
        uint256 collateralTokenId,
        uint256 maxPrincipalPerCollateralAmount,
        uint8 collateralTokenType,
        address lender,
        uint256 marketId,
        address principalTokenAddress
    );
    function getCommitmentMarketId(uint256 _commitmentId) external view returns (uint256);
}

interface IExtensionsContext {
    function addExtension(address extension) external;
}

/**
 * @title NFT Flash Swap Rollover Fork Test
 * @notice Tests SwapRolloverLoan (G4) rollover with ERC721 (ENS) collateral
 *         and a regular lender commitment on mainnet.
 *
 * Transaction being replayed:
 *   from:  0xBa758f9169Df248B764aA20bc835b5f1786dFC14
 *   to:    0x7848585b707F54CcF7044F8C82CF53F43100dc83  (SwapRolloverLoan)
 *   chain: mainnet (1)
 *
 * Loan details:
 *   - loanId: 4752
 *   - principal: WETH
 *   - collateral: ENS domain NFT (ERC721)
 *   - commitment: regular (LenderCommitmentForwarderStaging, id=201)
 *   - flash pool: USDC/WETH 0.05% on Uniswap V3
 *
 * Run with:
 *   FOUNDRY_PROFILE=fork forge test --match-contract NFT_FlashSwapRollover_Test -vvvv \
 *     --fork-url <MAINNET_RPC_URL>
 */
contract NFT_FlashSwapRollover_Test is Test {

    string constant NETWORK_NAME = "mainnet";

    using stdJson for string;

    // Mainnet addresses
    address constant USDC  = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH  = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant ENS_BASE_REGISTRAR = 0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85;

    // Transaction participants
    address constant BORROWER = 0xBa758f9169Df248B764aA20bc835b5f1786dFC14;
    address constant SWAP_ROLLOVER_ADDR = 0x7848585b707F54CcF7044F8C82CF53F43100dc83;
    address constant LCF_STAGING = 0x5098102507Da3F71677C5d9e170f91779Fe888F4;

    // Loan params from the raw tx
    uint256 constant LOAN_ID = 4752;  // 0x1290
    uint256 constant BORROWER_AMOUNT = 0x01be3dac9f1235f8;
    uint256 constant COMMITMENT_ID = 201;  // 0xc9
    uint256 constant PRINCIPAL_AMOUNT = 0x1b7a5fb088fe3c00;
    uint256 constant COLLATERAL_TOKEN_ID = 0xb2605082270870306ed4c304d0b1df22fad260b4f0aeaa593a619c44125232b1;
    uint256 constant FLASH_AMOUNT = 0x1c8f813559a7f2a1;
    uint16  constant INTEREST_RATE = 2400;   // 0x960
    uint32  constant LOAN_DURATION = 5184000; // 0x4f1a00 = 60 days

    SwapRolloverLoan swapRolloverLoan;

    function getDeployedAddress(string memory contractName) internal view returns (address) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/", NETWORK_NAME, "/", contractName, ".json");
        string memory json = vm.readFile(path);
        return json.readAddress(".address");
    }

    function setUp() public {
        swapRolloverLoan = SwapRolloverLoan(payable(SWAP_ROLLOVER_ADDR));
        assertTrue(SWAP_ROLLOVER_ADDR.code.length > 0, "SwapRolloverLoan not deployed");
        assertTrue(LCF_STAGING.code.length > 0, "LenderCommitmentForwarderStaging not deployed");
    }

    // ============ Diagnostic: inspect commitment minInterestRate ============

    function test_inspect_commitment() public {
        ILenderCommitmentForwarder_Debug lcf = ILenderCommitmentForwarder_Debug(LCF_STAGING);

        (
            uint256 maxPrincipal,
            uint32 expiration,
            uint32 maxDuration,
            uint16 minInterestRate,
            address collateralTokenAddress,
            uint256 collateralTokenId,
            uint256 maxPrincipalPerCollateralAmount,
            uint8 collateralTokenType,
            address lender,
            uint256 marketId,
            address principalTokenAddress
        ) = lcf.commitments(COMMITMENT_ID);

        console.log("=== Commitment #201 ===");
        console.log("  minInterestRate:", minInterestRate);
        console.log("  maxPrincipal:", maxPrincipal);
        console.log("  maxDuration:", maxDuration);
        console.log("  expiration:", expiration);
        console.log("  collateralTokenType:", collateralTokenType);
        console.log("  collateralTokenAddress:", collateralTokenAddress);
        console.log("  principalTokenAddress:", principalTokenAddress);
        console.log("  lender:", lender);
        console.log("  marketId:", marketId);
        console.log("  collateralTokenId:");
        console.logBytes32(bytes32(collateralTokenId));
        console.log("  maxPrincipalPerCollateralAmount:", maxPrincipalPerCollateralAmount);

        console.log("");
        console.log("  TX interestRate:", INTEREST_RATE);
        console.log("  Passes check?:", INTEREST_RATE >= minInterestRate);

        if (INTEREST_RATE < minInterestRate) {
            console.log("  >>> WILL REVERT: interestRate", INTEREST_RATE, "< minInterestRate", minInterestRate);
        }
    }

    // ============ Inspect loan state ============

    function test_inspect_loan() public {
        address tellerV2Addr = getDeployedAddress("TellerV2");
        ITellerV2 tellerV2 = ITellerV2(tellerV2Addr);

        address borrower = tellerV2.getLoanBorrower(LOAN_ID);
        address lendingToken = tellerV2.getLoanLendingToken(LOAN_ID);

        console.log("=== Loan #4752 ===");
        console.log("  borrower:", borrower);
        console.log("  lendingToken:", lendingToken);
        console.log("  expected borrower:", BORROWER);
        console.log("  match:", borrower == BORROWER);

        Payment memory owed = tellerV2.calculateAmountOwed(LOAN_ID, block.timestamp);
        console.log("  principal owed:", owed.principal);
        console.log("  interest owed:", owed.interest);
        console.log("  total owed:", owed.principal + owed.interest);
        console.log("  flashAmount:", FLASH_AMOUNT);

        // Check NFT ownership
        address nftOwner = IERC721(ENS_BASE_REGISTRAR).ownerOf(COLLATERAL_TOKEN_ID);
        console.log("  ENS NFT owner:", nftOwner);
    }

    // ============ Replay the rollover transaction ============

    function test_nft_flashswap_rollover() public {
        // Log pre-state
        _logPreState();

        SwapRolloverLoan_G2.FlashSwapArgs memory flashSwapArgs = SwapRolloverLoan_G2.FlashSwapArgs({
            token0: USDC,
            token1: WETH,
            fee: 500,
            flashAmount: FLASH_AMOUNT,
            borrowToken1: true
        });

        SwapRolloverLoan_G2.AcceptCommitmentArgs memory acceptCommitmentArgs = SwapRolloverLoan_G2.AcceptCommitmentArgs({
            commitmentId: COMMITMENT_ID,
            smartCommitmentAddress: address(0),
            principalAmount: PRINCIPAL_AMOUNT,
            collateralAmount: 1,
            collateralTokenId: COLLATERAL_TOKEN_ID,
            collateralTokenAddress: ENS_BASE_REGISTRAR,
            interestRate: INTEREST_RATE,
            loanDuration: LOAN_DURATION,
            merkleProof: new bytes32[](0)
        });

        vm.prank(BORROWER);
        swapRolloverLoan.rolloverLoanWithFlashSwap(
            LCF_STAGING,
            LOAN_ID,
            BORROWER_AMOUNT,
            flashSwapArgs,
            acceptCommitmentArgs
        );

        // Post-state verification
        _logPostState();
    }

    // ============ Replay via raw calldata decode ============

    function test_nft_flashswap_rollover_raw_calldata() public {
        bytes memory tx_calldata = hex"0f29fee20000000000000000000000005098102507da3f71677c5d9e170f91779fe888f4000000000000000000000000000000000000000000000000000000000000129000000000000000000000000000000000000000000000000001be3dac9f1235f8000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000000001f40000000000000000000000000000000000000000000000001c8f813559a7f2a10000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000c900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001b7a5fb088fe3c000000000000000000000000000000000000000000000000000000000000000001b2605082270870306ed4c304d0b1df22fad260b4f0aeaa593a619c44125232b100000000000000000000000057f1887a8bf19b14fc0df6fd9b2acc9af147ea85000000000000000000000000000000000000000000000000000000000000096000000000000000000000000000000000000000000000000000000000004f1a0000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000000";

        // Strip 4-byte selector
        bytes memory params = new bytes(tx_calldata.length - 4);
        for (uint i = 4; i < tx_calldata.length; i++) {
            params[i - 4] = tx_calldata[i];
        }

        (
            address decoded_lcf,
            uint256 decoded_loanId,
            uint256 decoded_borrowerAmount,
            SwapRolloverLoan_G2.FlashSwapArgs memory decoded_flashSwapArgs,
            SwapRolloverLoan_G2.AcceptCommitmentArgs memory decoded_acceptCommitmentArgs
        ) = abi.decode(params, (
            address,
            uint256,
            uint256,
            SwapRolloverLoan_G2.FlashSwapArgs,
            SwapRolloverLoan_G2.AcceptCommitmentArgs
        ));

        console.log("=== Decoded TX Parameters ===");
        console.log("  lenderCommitmentForwarder:", decoded_lcf);
        console.log("  loanId:", decoded_loanId);
        console.log("  borrowerAmount:", decoded_borrowerAmount);
        console.log("  flash token0:", decoded_flashSwapArgs.token0);
        console.log("  flash token1:", decoded_flashSwapArgs.token1);
        console.log("  flash fee:", decoded_flashSwapArgs.fee);
        console.log("  flashAmount:", decoded_flashSwapArgs.flashAmount);
        console.log("  borrowToken1:", decoded_flashSwapArgs.borrowToken1);
        console.log("  commitmentId:", decoded_acceptCommitmentArgs.commitmentId);
        console.log("  smartCommitmentAddress:", decoded_acceptCommitmentArgs.smartCommitmentAddress);
        console.log("  principalAmount:", decoded_acceptCommitmentArgs.principalAmount);
        console.log("  collateralAmount:", decoded_acceptCommitmentArgs.collateralAmount);
        console.log("  collateralTokenId:");
        console.logBytes32(bytes32(decoded_acceptCommitmentArgs.collateralTokenId));
        console.log("  collateralTokenAddress:", decoded_acceptCommitmentArgs.collateralTokenAddress);
        console.log("  interestRate:", decoded_acceptCommitmentArgs.interestRate);
        console.log("  loanDuration:", decoded_acceptCommitmentArgs.loanDuration);

        // Inspect commitment to diagnose minInterestRate issue
        ILenderCommitmentForwarder_Debug lcf = ILenderCommitmentForwarder_Debug(decoded_lcf);
        (,,,uint16 minInterestRate,,,,,,,) = lcf.commitments(decoded_acceptCommitmentArgs.commitmentId);
        console.log("");
        console.log("  commitment.minInterestRate:", minInterestRate);
        console.log("  tx interestRate:", decoded_acceptCommitmentArgs.interestRate);
        if (decoded_acceptCommitmentArgs.interestRate < minInterestRate) {
            console.log("  >>> MISMATCH: tx rate < commitment min rate!");
        }

        vm.prank(BORROWER);
        swapRolloverLoan.rolloverLoanWithFlashSwap(
            decoded_lcf,
            decoded_loanId,
            decoded_borrowerAmount,
            decoded_flashSwapArgs,
            decoded_acceptCommitmentArgs
        );

        console.log("Rollover succeeded!");
    }

    // ============ Helpers ============

    function _logPreState() internal {
        address tellerV2Addr = getDeployedAddress("TellerV2");
        ITellerV2 tellerV2 = ITellerV2(tellerV2Addr);

        console.log("=== Pre-Rollover State ===");

        address borrower = tellerV2.getLoanBorrower(LOAN_ID);
        console.log("  loan borrower:", borrower);

        Payment memory owed = tellerV2.calculateAmountOwed(LOAN_ID, block.timestamp);
        console.log("  total owed:", owed.principal + owed.interest);

        uint256 wethBal = IERC20(WETH).balanceOf(BORROWER);
        console.log("  borrower WETH balance:", wethBal);

        address nftOwner = IERC721(ENS_BASE_REGISTRAR).ownerOf(COLLATERAL_TOKEN_ID);
        console.log("  ENS NFT owner:", nftOwner);
    }

    function _logPostState() internal {
        address tellerV2Addr = getDeployedAddress("TellerV2");
        ITellerV2 tellerV2 = ITellerV2(tellerV2Addr);

        console.log("=== Post-Rollover State ===");

        Payment memory owed = tellerV2.calculateAmountOwed(LOAN_ID, block.timestamp);
        console.log("  old loan owed:", owed.principal + owed.interest);

        uint256 wethBal = IERC20(WETH).balanceOf(BORROWER);
        console.log("  borrower WETH balance:", wethBal);

        address nftOwner = IERC721(ENS_BASE_REGISTRAR).ownerOf(COLLATERAL_TOKEN_ID);
        console.log("  ENS NFT owner:", nftOwner);

        console.log("NFT flash swap rollover SUCCEEDED!");
    }
}
