// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { Testable } from "../Testable.sol";

import { TellerV2 } from "../../contracts/TellerV2.sol";
import { BidState } from "../../contracts/TellerV2Storage.sol";
import { MarketRegistry } from "../../contracts/MarketRegistry.sol";
import { ReputationManager } from "../../contracts/ReputationManager.sol";
import { CollateralManager } from "../../contracts/CollateralManager.sol";
import { CollateralEscrowV1 } from "../../contracts/escrow/CollateralEscrowV1.sol";
import { LenderManager } from "../../contracts/LenderManager.sol";
import { EscrowVault } from "../../contracts/EscrowVault.sol";
import { ProtocolPausingManager } from "../../contracts/pausing/ProtocolPausingManager.sol";
import { IMarketRegistry } from "../../contracts/interfaces/IMarketRegistry.sol";

import "../../contracts/EAS/TellerAS.sol";
import "../../contracts/EAS/TellerASEIP712Verifier.sol";
import "../../contracts/EAS/TellerASRegistry.sol";

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import { LenderCommitmentForwarderAlpha } from "../../contracts/LenderCommitmentForwarder/LenderCommitmentForwarderAlpha.sol";
import { LenderCommitmentForwarderStaged } from "../../contracts/LenderCommitmentForwarder/LenderCommitmentForwarderStaged.sol";
import { ILenderCommitmentForwarder_U1 } from "../../contracts/interfaces/ILenderCommitmentForwarder_U1.sol";

import { RomeEvmWrappedToken } from "../../contracts/tokens/RomeEvmWrappedToken.sol";
import { TestERC20Token } from "../tokens/TestERC20Token.sol";

import { PaymentType, PaymentCycleType } from "../../contracts/libraries/V2Calculations.sol";

/**
 * Integration test: a real TellerV2 suite with LenderCommitmentForwarderAlpha
 * as the global commitment forwarder (the Rome layout) and the staged
 * forwarder trusted per market.
 */
contract LenderCommitmentForwarderStaged_Test is Testable {
    event BidStaged(
        uint256 indexed bidId,
        uint256 indexed commitmentId,
        address indexed borrower,
        uint256 principal
    );
    event StagedBidAccepted(
        uint256 indexed bidId,
        uint256 indexed commitmentId,
        address indexed lender
    );
    event StagedBidReleased(
        uint256 indexed bidId,
        uint256 indexed commitmentId
    );

    TellerV2 tellerV2;
    MarketRegistry marketRegistry;
    CollateralManager collateralManager;
    LenderCommitmentForwarderAlpha alpha;
    LenderCommitmentForwarderStaged staged; // CHECK_LENDER_ON_ACCEPT = true
    LenderCommitmentForwarderStaged stagedNoCheck; // CHECK_LENDER_ON_ACCEPT = false

    TestERC20Token principalToken; // 6 decimals, like USDC
    TestERC20Token collateralToken; // 18 decimals

    address lender = makeAddr("lender");
    address borrower = makeAddr("borrower");
    address borrower2 = makeAddr("borrower2");
    address marketOwner = makeAddr("marketOwner");
    address recipient = makeAddr("recipient");

    uint256 marketId;

    uint16 constant PROTOCOL_FEE = 100; // 1%
    uint32 constant BID_EXPIRATION = 7 days;

    // 1 collateral token (1e18) borrows up to 2000 principal (2000e6)
    uint256 constant RATIO = 2000e6;
    uint256 constant MAX_PRINCIPAL = 10_000e6;

    function setUp() public {
        tellerV2 = new TellerV2(address(0));

        marketRegistry = new MarketRegistry();
        marketRegistry.initialize(
            new TellerAS(new TellerASRegistry(), new TellerASEIP712Verifier())
        );

        alpha = new LenderCommitmentForwarderAlpha(
            address(tellerV2),
            address(marketRegistry),
            address(0)
        );

        ReputationManager reputationManager = new ReputationManager();
        collateralManager = new CollateralManager();
        LenderManager lenderManager = new LenderManager(
            IMarketRegistry(address(marketRegistry))
        );
        EscrowVault escrowVault = new EscrowVault();
        ProtocolPausingManager pausingManager = new ProtocolPausingManager();
        pausingManager.initialize();
        collateralManager.initialize(
            address(new UpgradeableBeacon(address(new CollateralEscrowV1()))),
            address(tellerV2)
        );
        lenderManager.initialize();
        reputationManager.initialize(address(tellerV2));

        tellerV2.initialize(
            PROTOCOL_FEE,
            address(marketRegistry),
            address(reputationManager),
            address(alpha),
            address(collateralManager),
            address(lenderManager),
            address(escrowVault),
            address(pausingManager)
        );

        staged = new LenderCommitmentForwarderStaged(
            address(tellerV2),
            address(marketRegistry),
            address(alpha),
            true
        );
        stagedNoCheck = new LenderCommitmentForwarderStaged(
            address(tellerV2),
            address(marketRegistry),
            address(alpha),
            false
        );

        vm.prank(marketOwner);
        marketId = marketRegistry.createMarket(
            marketOwner,
            uint32(30 days),
            uint32(5 days),
            BID_EXPIRATION,
            0,
            false,
            false,
            PaymentType.EMI,
            PaymentCycleType.Seconds,
            "uri"
        );

        vm.prank(marketOwner);
        tellerV2.setTrustedMarketForwarder(marketId, address(staged));

        principalToken = new TestERC20Token("USD", "USD", 1_000_000e6, 6);
        collateralToken = new TestERC20Token("COL", "COL", 1_000_000e18, 18);

        principalToken.transfer(lender, 100_000e6);
        collateralToken.transfer(borrower, 100e18);
        collateralToken.transfer(borrower2, 100e18);

        // lender: approve the staged forwarder and Alpha, and TellerV2 for principal
        vm.startPrank(lender);
        tellerV2.approveMarketForwarder(marketId, address(staged));
        tellerV2.approveMarketForwarder(marketId, address(alpha));
        principalToken.approve(address(tellerV2), type(uint256).max);
        vm.stopPrank();

        _approveBorrower(borrower);
        _approveBorrower(borrower2);
    }

    function _approveBorrower(address _borrower) internal {
        vm.startPrank(_borrower);
        tellerV2.approveMarketForwarder(marketId, address(staged));
        tellerV2.approveMarketForwarder(marketId, address(alpha));
        collateralToken.approve(address(collateralManager), type(uint256).max);
        vm.stopPrank();
    }

    function _commitment()
        internal
        view
        returns (ILenderCommitmentForwarder_U1.Commitment memory c)
    {
        c.maxPrincipal = MAX_PRINCIPAL;
        c.expiration = uint32(block.timestamp + 30 days);
        c.maxDuration = uint32(365 days);
        c.minInterestRate = 500;
        c.collateralTokenAddress = address(collateralToken);
        c.collateralTokenId = 0;
        c.maxPrincipalPerCollateralAmount = RATIO;
        c.collateralTokenType = ILenderCommitmentForwarder_U1
            .CommitmentCollateralType
            .ERC20;
        c.lender = lender;
        c.marketId = marketId;
        c.principalTokenAddress = address(principalToken);
    }

    function _create(
        ILenderCommitmentForwarder_U1.Commitment memory c,
        address[] memory borrowers
    ) internal returns (uint256 id) {
        vm.prank(c.lender);
        id = alpha.createCommitmentWithUniswap(
            c,
            borrowers,
            new ILenderCommitmentForwarder_U1.PoolRouteConfig[](0),
            0
        );
    }

    function _createDefault() internal returns (uint256) {
        return _create(_commitment(), new address[](0));
    }

    function _stage(
        LenderCommitmentForwarderStaged fwd,
        address _borrower,
        uint256 commitmentId,
        uint256 principal,
        uint256 collateral
    ) internal returns (uint256 bidId) {
        vm.prank(_borrower);
        bidId = fwd.submitStagedCommitmentBid(
            commitmentId,
            principal,
            collateral,
            0,
            address(collateralToken),
            recipient,
            1000,
            uint32(180 days)
        );
    }

    function _stage(
        address _borrower,
        uint256 commitmentId,
        uint256 principal,
        uint256 collateral
    ) internal returns (uint256) {
        return _stage(staged, _borrower, commitmentId, principal, collateral);
    }

    // ---------------------------------------------------------------- happy path

    function test_constructor() public {
        assertEq(address(staged.ALPHA()), address(alpha));
        assertTrue(staged.CHECK_LENDER_ON_ACCEPT());
        assertFalse(stagedNoCheck.CHECK_LENDER_ON_ACCEPT());
        assertEq(staged.getTellerV2(), address(tellerV2));
        assertEq(staged.getMarketRegistry(), address(marketRegistry));
    }

    function test_two_step_happy_path() public {
        uint256 commitmentId = _createDefault();
        uint256 principal = 1000e6;
        uint256 collateral = 0.5e18; // exactly required

        vm.expectEmit(true, true, true, true, address(staged));
        emit BidStaged(0, commitmentId, borrower, principal);
        uint256 bidId = _stage(borrower, commitmentId, principal, collateral);

        assertEq(
            uint256(tellerV2.getBidState(bidId)),
            uint256(BidState.PENDING)
        );
        assertEq(tellerV2.getLoanBorrower(bidId), borrower);
        (uint256 cId, address l, uint256 p) = staged.stagedBids(bidId);
        assertEq(cId, commitmentId);
        assertEq(l, lender);
        assertEq(p, principal);
        assertFalse(staged.isStagedBidAccepted(bidId));
        assertEq(staged.stagedPrincipal(commitmentId), principal);
        // Alpha's own accounting is untouched
        assertEq(alpha.getCommitmentAcceptedPrincipal(commitmentId), 0);

        uint256 lenderBefore = principalToken.balanceOf(lender);

        vm.expectEmit(true, true, true, true, address(staged));
        emit StagedBidAccepted(bidId, commitmentId, lender);
        // permissionless: a third party may trigger the accept
        vm.prank(makeAddr("anyone"));
        (uint256 toProtocol, uint256 toMarket, uint256 toBorrower) = staged
            .acceptStagedCommitmentBid(bidId);

        assertEq(toProtocol, 10e6);
        assertEq(toMarket, 0);
        assertEq(toBorrower, 990e6);

        assertEq(
            uint256(tellerV2.getBidState(bidId)),
            uint256(BidState.ACCEPTED)
        );
        assertEq(tellerV2.getLoanLender(bidId), lender);
        assertEq(lenderBefore - principalToken.balanceOf(lender), principal);
        assertEq(principalToken.balanceOf(recipient), 990e6);

        address escrow = collateralManager.getEscrow(bidId);
        assertTrue(escrow != address(0));
        assertEq(collateralToken.balanceOf(escrow), collateral);
        assertEq(collateralToken.balanceOf(borrower), 100e18 - collateral);

        assertTrue(staged.isStagedBidAccepted(bidId));
        (cId, l, p) = staged.stagedBids(bidId);
        assertEq(cId, commitmentId);
        assertEq(l, lender);
        assertEq(p, principal);
        // reservation is kept: the principal is now lent
        assertEq(staged.stagedPrincipal(commitmentId), principal);
    }

    function test_recipient_zero_pays_borrower() public {
        uint256 commitmentId = _createDefault();
        vm.prank(borrower);
        uint256 bidId = staged.submitStagedCommitmentBid(
            commitmentId,
            100e6,
            1e18,
            0,
            address(collateralToken),
            address(0),
            500,
            uint32(365 days)
        );
        staged.acceptStagedCommitmentBid(bidId);
        assertEq(principalToken.balanceOf(borrower), 99e6);
    }

    function test_stagedPrincipal_accumulates() public {
        uint256 commitmentId = _createDefault();
        _stage(borrower, commitmentId, 1000e6, 1e18);
        _stage(borrower2, commitmentId, 2000e6, 1e18);
        assertEq(staged.stagedPrincipal(commitmentId), 3000e6);
    }

    // ------------------------------------------------------------- validation

    function test_submit_reverts_unknown_commitment() public {
        vm.expectRevert("unknown commitment");
        _stage(borrower, 42, 100e6, 1e18);
    }

    function test_submit_reverts_deleted_commitment() public {
        uint256 commitmentId = _createDefault();
        vm.prank(lender);
        alpha.deleteCommitment(commitmentId);
        vm.expectRevert("unknown commitment");
        _stage(borrower, commitmentId, 100e6, 1e18);
    }

    function test_submit_reverts_non_erc20_collateral() public {
        ILenderCommitmentForwarder_U1.Commitment memory c = _commitment();
        c.collateralTokenType = ILenderCommitmentForwarder_U1
            .CommitmentCollateralType
            .ERC721;
        c.maxPrincipalPerCollateralAmount = 1000e6;
        uint256 commitmentId = _create(c, new address[](0));

        vm.expectRevert("Invalid commitment collateral type");
        _stage(borrower, commitmentId, 100e6, 1);
    }

    function test_submit_reverts_no_collateral_type() public {
        ILenderCommitmentForwarder_U1.Commitment memory c = _commitment();
        c.collateralTokenType = ILenderCommitmentForwarder_U1
            .CommitmentCollateralType
            .NONE;
        uint256 commitmentId = _create(c, new address[](0));

        vm.expectRevert("Invalid commitment collateral type");
        _stage(borrower, commitmentId, 100e6, 0);
    }

    function test_submit_reverts_with_pool_routes() public {
        ILenderCommitmentForwarder_U1.PoolRouteConfig[]
            memory routes = new ILenderCommitmentForwarder_U1.PoolRouteConfig[](
                1
            );
        routes[0].pool = makeAddr("pool");
        vm.prank(lender);
        uint256 commitmentId = alpha.createCommitmentWithUniswap(
            _commitment(),
            new address[](0),
            routes,
            7000
        );

        vm.expectRevert("oracle-priced commitment");
        _stage(borrower, commitmentId, 100e6, 1e18);
    }

    function test_submit_reverts_expired() public {
        uint256 commitmentId = _createDefault();
        vm.warp(block.timestamp + 31 days);
        vm.expectRevert("expired commitment");
        _stage(borrower, commitmentId, 100e6, 1e18);
    }

    function test_submit_reverts_collateral_token_mismatch() public {
        uint256 commitmentId = _createDefault();
        vm.prank(borrower);
        vm.expectRevert("Mismatching collateral token");
        staged.submitStagedCommitmentBid(
            commitmentId,
            100e6,
            1e18,
            0,
            address(principalToken),
            recipient,
            1000,
            uint32(180 days)
        );
    }

    function test_submit_reverts_interest_rate_too_low() public {
        uint256 commitmentId = _createDefault();
        vm.prank(borrower);
        vm.expectRevert("Invalid interest rate");
        staged.submitStagedCommitmentBid(
            commitmentId,
            100e6,
            1e18,
            0,
            address(collateralToken),
            recipient,
            499,
            uint32(180 days)
        );
    }

    function test_submit_reverts_duration_too_long() public {
        uint256 commitmentId = _createDefault();
        vm.prank(borrower);
        vm.expectRevert("Invalid loan max duration");
        staged.submitStagedCommitmentBid(
            commitmentId,
            100e6,
            1e18,
            0,
            address(collateralToken),
            recipient,
            1000,
            uint32(365 days + 1)
        );
    }

    function test_submit_reverts_principal_above_max() public {
        uint256 commitmentId = _createDefault();
        vm.expectRevert(
            abi.encodeWithSelector(
                LenderCommitmentForwarderStaged
                    .InsufficientCommitmentAllocation
                    .selector,
                MAX_PRINCIPAL,
                MAX_PRINCIPAL + 1
            )
        );
        _stage(borrower, commitmentId, MAX_PRINCIPAL + 1, 100e18);
    }

    function test_submit_reverts_insufficient_collateral() public {
        uint256 commitmentId = _createDefault();
        // 1000e6 principal needs 0.5e18 collateral; rounding is up
        vm.expectRevert(
            abi.encodeWithSelector(
                LenderCommitmentForwarderStaged
                    .InsufficientBorrowerCollateral
                    .selector,
                0.5e18,
                0.5e18 - 1
            )
        );
        _stage(borrower, commitmentId, 1000e6, 0.5e18 - 1);
    }

    function test_required_collateral_rounds_up() public {
        uint256 commitmentId = _createDefault();
        // 1 unit of principal needs ceil(1e18 / 2000e6) = 500000000 collateral
        vm.expectRevert(
            abi.encodeWithSelector(
                LenderCommitmentForwarderStaged
                    .InsufficientBorrowerCollateral
                    .selector,
                500000000,
                499999999
            )
        );
        _stage(borrower, commitmentId, 1, 499999999);
        _stage(borrower, commitmentId, 1, 500000000);

        // a non-divisible case: 3 units with ratio 7 per 1e18
        ILenderCommitmentForwarder_U1.Commitment memory c = _commitment();
        c.maxPrincipalPerCollateralAmount = 7;
        uint256 id2 = _create(c, new address[](0));
        uint256 numerator = 3 * 1e18 + 6;
        uint256 required = numerator / 7; // ceil(3e18 / 7)
        vm.expectRevert(
            abi.encodeWithSelector(
                LenderCommitmentForwarderStaged
                    .InsufficientBorrowerCollateral
                    .selector,
                required,
                required - 1
            )
        );
        _stage(borrower, id2, 3, required - 1);
    }

    function test_submit_reverts_without_borrower_forwarder_approval() public {
        uint256 commitmentId = _createDefault();
        address stranger = makeAddr("stranger");
        collateralToken.transfer(stranger, 1e18);
        vm.expectRevert("Sender must approve market forwarder");
        _stage(stranger, commitmentId, 100e6, 1e18);
    }

    // --------------------------------------------------------------- allowlist

    function test_allowlist() public {
        address[] memory allowed = new address[](1);
        allowed[0] = borrower2;
        uint256 commitmentId = _create(_commitment(), allowed);

        vm.expectRevert("unauthorized commitment borrower");
        _stage(borrower, commitmentId, 100e6, 1e18);

        uint256 bidId = _stage(borrower2, commitmentId, 100e6, 1e18);
        staged.acceptStagedCommitmentBid(bidId);
        assertEq(tellerV2.getLoanBorrower(bidId), borrower2);
    }

    // ------------------------------------------------------------ maxPrincipal

    function test_max_principal_counts_alpha_accepted_and_staged() public {
        uint256 commitmentId = _createDefault(); // 10_000e6

        // 4000 through Alpha's single-transaction path
        vm.prank(borrower);
        alpha.acceptCommitmentWithRecipient(
            commitmentId,
            4000e6,
            2e18,
            0,
            address(collateralToken),
            borrower,
            500,
            uint32(180 days)
        );
        assertEq(alpha.getCommitmentAcceptedPrincipal(commitmentId), 4000e6);

        // 5000 staged (one accepted, one pending)
        uint256 bid1 = _stage(borrower, commitmentId, 3000e6, 2e18);
        staged.acceptStagedCommitmentBid(bid1);
        _stage(borrower2, commitmentId, 2000e6, 1e18);
        assertEq(staged.stagedPrincipal(commitmentId), 5000e6);

        // 1000e6 left
        vm.expectRevert("Exceeds max principal of commitment");
        _stage(borrower, commitmentId, 1000e6 + 1, 1e18);

        _stage(borrower, commitmentId, 1000e6, 1e18);
        assertEq(staged.stagedPrincipal(commitmentId), 6000e6);

        vm.expectRevert("Exceeds max principal of commitment");
        _stage(borrower, commitmentId, 1, 1e18);
    }

    function test_release_frees_principal_for_new_stage() public {
        uint256 commitmentId = _createDefault();
        uint256 bidId = _stage(borrower, commitmentId, MAX_PRINCIPAL, 5e18);

        vm.expectRevert("Exceeds max principal of commitment");
        _stage(borrower2, commitmentId, 1, 1e18);

        vm.prank(borrower);
        tellerV2.cancelBid(bidId);
        staged.releaseStagedBid(bidId);

        _stage(borrower2, commitmentId, MAX_PRINCIPAL, 5e18);
    }

    // ------------------------------------------------------------------ accept

    function test_accept_reverts_not_staged() public {
        vm.expectRevert("bid not staged");
        staged.acceptStagedCommitmentBid(0);
    }

    function test_accept_cannot_be_called_twice() public {
        uint256 commitmentId = _createDefault();
        uint256 bidId = _stage(borrower, commitmentId, 100e6, 1e18);
        staged.acceptStagedCommitmentBid(bidId);
        vm.expectRevert("bid already accepted");
        staged.acceptStagedCommitmentBid(bidId);
    }

    function test_accept_reverts_cancelled_bid() public {
        uint256 commitmentId = _createDefault();
        uint256 bidId = _stage(borrower, commitmentId, 100e6, 1e18);
        vm.prank(borrower);
        tellerV2.cancelBid(bidId);
        vm.expectRevert(); // TellerV2: ActionNotAllowed "Bid not pending"
        staged.acceptStagedCommitmentBid(bidId);
        assertFalse(staged.isStagedBidAccepted(bidId));
    }

    function test_accept_reverts_expired_bid() public {
        uint256 commitmentId = _createDefault();
        uint256 bidId = _stage(borrower, commitmentId, 100e6, 1e18);
        vm.warp(block.timestamp + BID_EXPIRATION + 1);
        vm.expectRevert(bytes("BE"));
        staged.acceptStagedCommitmentBid(bidId);
    }

    function test_accept_reverts_when_lender_renounced_forwarder() public {
        uint256 commitmentId = _createDefault();
        uint256 bidId = _stage(borrower, commitmentId, 100e6, 1e18);
        vm.prank(lender);
        tellerV2.renounceMarketForwarder(marketId, address(staged));
        vm.expectRevert("Sender must approve market forwarder");
        staged.acceptStagedCommitmentBid(bidId);
    }

    function test_lender_check_on_blocks_deleted_commitment() public {
        uint256 commitmentId = _createDefault();
        uint256 bidId = _stage(borrower, commitmentId, 100e6, 1e18);
        vm.prank(lender);
        alpha.deleteCommitment(commitmentId);
        vm.expectRevert("commitment lender changed");
        staged.acceptStagedCommitmentBid(bidId);
    }

    function test_lender_check_off_ignores_deleted_commitment() public {
        vm.prank(marketOwner);
        tellerV2.setTrustedMarketForwarder(marketId, address(stagedNoCheck));
        vm.prank(lender);
        tellerV2.approveMarketForwarder(marketId, address(stagedNoCheck));
        vm.prank(borrower);
        tellerV2.approveMarketForwarder(marketId, address(stagedNoCheck));

        uint256 commitmentId = _createDefault();
        uint256 bidId = _stage(
            stagedNoCheck,
            borrower,
            commitmentId,
            100e6,
            1e18
        );
        vm.prank(lender);
        alpha.deleteCommitment(commitmentId);

        stagedNoCheck.acceptStagedCommitmentBid(bidId);
        assertEq(
            uint256(tellerV2.getBidState(bidId)),
            uint256(BidState.ACCEPTED)
        );
        assertEq(tellerV2.getLoanLender(bidId), lender);
    }

    function test_lender_check_on_happy_path_still_accepts() public {
        uint256 commitmentId = _createDefault();
        uint256 bidId = _stage(borrower, commitmentId, 100e6, 1e18);
        // an update that keeps the lender does not block acceptance
        ILenderCommitmentForwarder_U1.Commitment memory c = _commitment();
        c.minInterestRate = 2000;
        vm.prank(lender);
        alpha.updateCommitment(commitmentId, c);
        staged.acceptStagedCommitmentBid(bidId);
        assertEq(
            uint256(tellerV2.getBidState(bidId)),
            uint256(BidState.ACCEPTED)
        );
    }

    // ----------------------------------------------------------------- release

    function test_release_reverts_while_pending() public {
        uint256 commitmentId = _createDefault();
        uint256 bidId = _stage(borrower, commitmentId, 100e6, 1e18);
        vm.expectRevert("bid still pending");
        staged.releaseStagedBid(bidId);
        // still pending at exactly the expiration boundary
        vm.warp(block.timestamp + BID_EXPIRATION);
        vm.expectRevert("bid still pending");
        staged.releaseStagedBid(bidId);
    }

    function test_release_reverts_not_staged() public {
        vm.expectRevert("bid not staged");
        staged.releaseStagedBid(7);
    }

    function test_release_reverts_after_accept() public {
        uint256 commitmentId = _createDefault();
        uint256 bidId = _stage(borrower, commitmentId, 100e6, 1e18);
        staged.acceptStagedCommitmentBid(bidId);
        vm.expectRevert("bid already accepted");
        staged.releaseStagedBid(bidId);
    }

    function test_release_cancelled_bid() public {
        uint256 commitmentId = _createDefault();
        uint256 bidId = _stage(borrower, commitmentId, 100e6, 1e18);
        _stage(borrower2, commitmentId, 200e6, 1e18);

        vm.prank(borrower);
        tellerV2.cancelBid(bidId);

        vm.expectEmit(true, true, false, true, address(staged));
        emit StagedBidReleased(bidId, commitmentId);
        vm.prank(makeAddr("anyone"));
        staged.releaseStagedBid(bidId);

        assertEq(staged.stagedPrincipal(commitmentId), 200e6);
        (uint256 cId, address l, uint256 p) = staged.stagedBids(bidId);
        assertEq(cId, 0);
        assertEq(l, address(0));
        assertEq(p, 0);

        vm.expectRevert("bid not staged");
        staged.releaseStagedBid(bidId);
        vm.expectRevert("bid not staged");
        staged.acceptStagedCommitmentBid(bidId);
    }

    function test_release_expired_bid() public {
        uint256 commitmentId = _createDefault();
        uint256 bidId = _stage(borrower, commitmentId, 100e6, 1e18);
        vm.warp(block.timestamp + BID_EXPIRATION + 1);
        assertTrue(tellerV2.isLoanExpired(bidId));
        staged.releaseStagedBid(bidId);
        assertEq(staged.stagedPrincipal(commitmentId), 0);
    }

    function test_release_bid_accepted_outside_forwarder() public {
        uint256 commitmentId = _createDefault();
        uint256 bidId = _stage(borrower, commitmentId, 100e6, 1e18);

        // another lender accepts the bid directly on TellerV2
        address otherLender = makeAddr("otherLender");
        principalToken.transfer(otherLender, 1000e6);
        vm.startPrank(otherLender);
        principalToken.approve(address(tellerV2), type(uint256).max);
        tellerV2.lenderAcceptBid(bidId);
        vm.stopPrank();

        staged.releaseStagedBid(bidId);
        assertEq(staged.stagedPrincipal(commitmentId), 0);
    }

    // ----------------------------------------------------------------- wrapper

    function test_wrapped_token_deposit_withdraw() public {
        RomeEvmWrappedToken wrapped = new RomeEvmWrappedToken(
            principalToken,
            "Teller EVM USD",
            "teUSD"
        );
        assertEq(wrapped.name(), "Teller EVM USD");
        assertEq(wrapped.symbol(), "teUSD");
        assertEq(wrapped.decimals(), 6);
        assertEq(address(wrapped.underlying()), address(principalToken));

        RomeEvmWrappedToken wrapped18 = new RomeEvmWrappedToken(
            collateralToken,
            "Teller EVM COL",
            "teCOL"
        );
        assertEq(wrapped18.decimals(), 18);

        address user = makeAddr("user");
        address other = makeAddr("other");
        principalToken.transfer(user, 500e6);

        vm.startPrank(user);
        principalToken.approve(address(wrapped), 500e6);
        wrapped.depositFor(user, 300e6);
        wrapped.depositFor(other, 200e6);
        vm.stopPrank();

        assertEq(wrapped.balanceOf(user), 300e6);
        assertEq(wrapped.balanceOf(other), 200e6);
        assertEq(wrapped.totalSupply(), 500e6);
        assertEq(principalToken.balanceOf(address(wrapped)), 500e6);
        assertEq(principalToken.balanceOf(user), 0);

        vm.prank(user);
        wrapped.withdrawTo(other, 100e6);
        assertEq(wrapped.balanceOf(user), 200e6);
        assertEq(principalToken.balanceOf(other), 100e6);
        assertEq(wrapped.totalSupply(), 400e6);

        vm.prank(user);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        wrapped.withdrawTo(user, 200e6 + 1);

        vm.prank(other);
        vm.expectRevert("ERC20: insufficient allowance");
        wrapped.depositFor(other, 1);
    }

    function test_wrapped_tokens_through_staged_loan() public {
        RomeEvmWrappedToken wPrincipal = new RomeEvmWrappedToken(
            principalToken,
            "Teller EVM USD",
            "teUSD"
        );
        RomeEvmWrappedToken wCollateral = new RomeEvmWrappedToken(
            collateralToken,
            "Teller EVM COL",
            "teCOL"
        );

        vm.startPrank(lender);
        principalToken.approve(address(wPrincipal), 1000e6);
        wPrincipal.depositFor(lender, 1000e6);
        wPrincipal.approve(address(tellerV2), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(borrower);
        collateralToken.approve(address(wCollateral), 1e18);
        wCollateral.depositFor(borrower, 1e18);
        wCollateral.approve(address(collateralManager), type(uint256).max);
        vm.stopPrank();

        ILenderCommitmentForwarder_U1.Commitment memory c = _commitment();
        c.principalTokenAddress = address(wPrincipal);
        c.collateralTokenAddress = address(wCollateral);
        uint256 commitmentId = _create(c, new address[](0));

        vm.prank(borrower);
        uint256 bidId = staged.submitStagedCommitmentBid(
            commitmentId,
            1000e6,
            1e18,
            0,
            address(wCollateral),
            borrower,
            500,
            uint32(30 days)
        );
        staged.acceptStagedCommitmentBid(bidId);

        assertEq(wPrincipal.balanceOf(borrower), 990e6);
        assertEq(
            wCollateral.balanceOf(collateralManager.getEscrow(bidId)),
            1e18
        );

        vm.prank(borrower);
        wPrincipal.withdrawTo(borrower, 990e6);
        assertEq(principalToken.balanceOf(borrower), 990e6);
    }
}
