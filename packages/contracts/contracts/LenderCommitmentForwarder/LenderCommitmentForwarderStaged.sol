// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../TellerV2MarketForwarder_G2.sol";

import { BidState } from "../TellerV2Storage.sol";
import { ITellerV2 } from "../interfaces/ITellerV2.sol";
import { ILenderCommitmentForwarder_U1 } from "../interfaces/ILenderCommitmentForwarder_U1.sol";
import { Collateral, CollateralType } from "../interfaces/escrow/ICollateralEscrowV1.sol";
import { MathUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

/**
 * @dev The read-only surface of LenderCommitmentForwarderAlpha (U1) that the
 * staged forwarder uses. `commitments` is Alpha's public mapping getter; every
 * field of `Commitment` is static, so the getter's flat return tuple has the
 * same ABI encoding as the struct.
 */
interface ILenderCommitmentForwarderAlphaReader {
    function commitments(uint256 _commitmentId)
        external
        view
        returns (ILenderCommitmentForwarder_U1.Commitment memory);

    function getCommitmentBorrowers(uint256 _commitmentId)
        external
        view
        returns (address[] memory);

    function getCommitmentAcceptedPrincipal(uint256 _commitmentId)
        external
        view
        returns (uint256);

    function getCommitmentLender(uint256 _commitmentId)
        external
        view
        returns (address);

    function getAllCommitmentUniswapPoolRoutes(uint256 _commitmentId)
        external
        view
        returns (ILenderCommitmentForwarder_U1.PoolRouteConfig[] memory);
}

/// @dev TellerV2 views used by {LenderCommitmentForwarderStaged-releaseStagedBid}.
interface ITellerV2BidStatus {
    function getBidState(uint256 _bidId) external view returns (BidState);

    function isLoanExpired(uint256 _bidId) external view returns (bool);
}

/**
 * @title LenderCommitmentForwarderStaged
 * @notice Accepts lending offers (commitments) created on the existing
 * LenderCommitmentForwarderAlpha in two transactions instead of one:
 *
 *  1. {submitStagedCommitmentBid} - the borrower submits a TellerV2 bid on the
 *     commitment's terms. The terms are validated here against the commitment
 *     read from Alpha, exactly as Alpha's own accept path validates them.
 *  2. {acceptStagedCommitmentBid} - the bid is accepted on behalf of the
 *     commitment's lender, which pays out the principal and escrows the
 *     collateral.
 *
 * Splitting the accept keeps each transaction small enough for EVMs that cap
 * how much state a single transaction may touch (Rome caps it at 64 Solana
 * accounts). Lenders keep creating and managing commitments on Alpha; only the
 * borrower's accept path changes.
 *
 * Scope: ERC20 collateral only, and only commitments without Uniswap pool
 * routes (statically priced offers). Oracle-priced offers revert.
 *
 * Principal accounting: Alpha's own `commitmentPrincipalAccepted` is not
 * touched by this contract. Instead {stagedPrincipal} tracks the principal of
 * bids staged here (pending or accepted through this forwarder), and a new
 * stage must fit in `maxPrincipal - Alpha accepted - stagedPrincipal`.
 * Principal accepted through Alpha's single-transaction path and through this
 * contract therefore share one `maxPrincipal` budget. A staged bid that is never
 * accepted (cancelled or expired on TellerV2) can be released by anyone with
 * {releaseStagedBid}, returning its principal to the offer.
 *
 * Setup, all on TellerV2:
 *  - The market owner calls `setTrustedMarketForwarder(marketId, address(this))`.
 *    (Where Alpha is the global commitment forwarder, the per-market slot is
 *    free for this contract.)
 *  - The lender calls `approveMarketForwarder(marketId, address(this))`, so this
 *    contract may accept bids in the lender's name.
 *  - The borrower calls `approveMarketForwarder(marketId, address(this))`, so
 *    this contract may submit bids in the borrower's name.
 * The usual token approvals still apply: the lender approves TellerV2 for the
 * principal token and the borrower approves the CollateralManager for the
 * collateral token before step 2.
 *
 * Lender controls: accept does not re-read the commitment (every extra read is
 * state the accept transaction must touch). Terms are fixed when a bid is
 * staged and stay acceptable until TellerV2 expires the bid (the market's bid
 * expiration time). A lender who wants to stop pending staged bids from being
 * accepted calls `TellerV2.renounceMarketForwarder(marketId, address(this))`.
 * When {CHECK_LENDER_ON_ACCEPT} is set, deleting the commitment on Alpha also
 * blocks acceptance of its pending staged bids.
 *
 * Non-upgradeable on purpose: every proxy hop costs state on Rome.
 */
contract LenderCommitmentForwarderStaged is TellerV2MarketForwarder_G2 {
    /**
     * @dev Storage record for a staged bid, packed so that accept reads and
     * writes a single slot (lender, commitment id and accepted flag) and never
     * touches the principal slot.
     */
    struct StagedBidRecord {
        address lender;
        uint88 commitmentId;
        bool accepted;
        uint256 principal;
    }

    /// @notice The LenderCommitmentForwarderAlpha whose commitments this contract accepts.
    ILenderCommitmentForwarderAlphaReader public immutable ALPHA;

    /// @notice When true, accept also requires Alpha to still report the staged lender as the commitment's lender.
    bool public immutable CHECK_LENDER_ON_ACCEPT;

    uint256 private constant STANDARD_EXPANSION_FACTOR = 1e18;

    mapping(uint256 => StagedBidRecord) private _stagedBids;

    /// @notice commitmentId => principal reserved by staged bids that have not been released (pending, or accepted through this forwarder).
    mapping(uint256 => uint256) public stagedPrincipal;

    /**
     * @notice Emitted when a borrower stages a bid against a commitment.
     * @param bidId The TellerV2 bid id.
     * @param commitmentId The Alpha commitment id.
     * @param borrower The borrower of the bid.
     * @param principal The principal of the bid.
     */
    event BidStaged(
        uint256 indexed bidId,
        uint256 indexed commitmentId,
        address indexed borrower,
        uint256 principal
    );

    /**
     * @notice Emitted when a staged bid is accepted on behalf of the commitment's lender.
     * @param bidId The TellerV2 bid id.
     * @param commitmentId The Alpha commitment id.
     * @param lender The lender that funded the loan.
     */
    event StagedBidAccepted(
        uint256 indexed bidId,
        uint256 indexed commitmentId,
        address indexed lender
    );

    /**
     * @notice Emitted when a staged bid that was never accepted is released and its principal returned to the commitment.
     * @param bidId The TellerV2 bid id.
     * @param commitmentId The Alpha commitment id.
     */
    event StagedBidReleased(
        uint256 indexed bidId,
        uint256 indexed commitmentId
    );

    error InsufficientCommitmentAllocation(
        uint256 allocated,
        uint256 requested
    );
    error InsufficientBorrowerCollateral(uint256 required, uint256 actual);

    /**
     * @param _tellerV2 The TellerV2 proxy.
     * @param _marketRegistry The MarketRegistry proxy.
     * @param _alpha The LenderCommitmentForwarderAlpha proxy.
     * @param _checkLenderOnAccept Whether accept re-reads the commitment lender from Alpha (see {CHECK_LENDER_ON_ACCEPT}).
     */
    constructor(
        address _tellerV2,
        address _marketRegistry,
        address _alpha,
        bool _checkLenderOnAccept
    ) TellerV2MarketForwarder_G2(_tellerV2, _marketRegistry) {
        ALPHA = ILenderCommitmentForwarderAlphaReader(_alpha);
        CHECK_LENDER_ON_ACCEPT = _checkLenderOnAccept;
    }

    /**
     * @notice The staged bid recorded for a TellerV2 bid id. All zero when none
     * is recorded (never staged, or released).
     * @param _bidId The TellerV2 bid id.
     * @return commitmentId The Alpha commitment id the bid was staged against.
     * @return lender The commitment's lender at staging time.
     * @return principal The principal of the bid.
     */
    function stagedBids(uint256 _bidId)
        external
        view
        returns (uint256 commitmentId, address lender, uint256 principal)
    {
        StagedBidRecord storage s = _stagedBids[_bidId];
        return (s.commitmentId, s.lender, s.principal);
    }

    /**
     * @notice Whether a staged bid has been accepted through this forwarder.
     * @param _bidId The TellerV2 bid id.
     */
    function isStagedBidAccepted(uint256 _bidId) external view returns (bool) {
        return _stagedBids[_bidId].accepted;
    }

    /**
     * @notice Step 1: submit a TellerV2 bid on the terms of an Alpha commitment.
     * The caller is the borrower and must have approved this forwarder on
     * TellerV2 for the commitment's market.
     * @param _commitmentId The Alpha commitment id.
     * @param _principalAmount The principal to borrow.
     * @param _collateralAmount The ERC20 collateral amount to commit.
     * @param _collateralTokenId Unused (ERC20 collateral has no token id); kept so the arguments match Alpha's `acceptCommitmentWithRecipient`.
     * @param _collateralTokenAddress Must equal the commitment's collateral token.
     * @param _recipient Receives the principal; zero means the borrower.
     * @param _interestRate APR in basis points; at least the commitment's minimum.
     * @param _loanDuration Loan duration in seconds; at most the commitment's maximum.
     * @return bidId The TellerV2 bid id.
     */
    function submitStagedCommitmentBid(
        uint256 _commitmentId,
        uint256 _principalAmount,
        uint256 _collateralAmount,
        uint256 _collateralTokenId,
        address _collateralTokenAddress,
        address _recipient,
        uint16 _interestRate,
        uint32 _loanDuration
    ) external returns (uint256 bidId) {
        _collateralTokenId; // unused for ERC20 collateral

        address borrower = _msgSender();

        ILenderCommitmentForwarder_U1.Commitment
            memory commitment = _validateAndReserve(
                _commitmentId,
                _principalAmount,
                _collateralAmount,
                _collateralTokenAddress,
                _interestRate,
                _loanDuration,
                borrower
            );

        CreateLoanArgs memory createLoanArgs;
        createLoanArgs.marketId = commitment.marketId;
        createLoanArgs.lendingToken = commitment.principalTokenAddress;
        createLoanArgs.principal = _principalAmount;
        createLoanArgs.duration = _loanDuration;
        createLoanArgs.interestRate = _interestRate;
        createLoanArgs.recipient = _recipient;
        createLoanArgs.collateral = new Collateral[](1);
        createLoanArgs.collateral[0] = Collateral({
            _collateralType: CollateralType.ERC20,
            _amount: _collateralAmount,
            _tokenId: 0,
            _collateralAddress: commitment.collateralTokenAddress
        });

        bidId = _submitBidWithCollateral(createLoanArgs, borrower);

        _stagedBids[bidId] = StagedBidRecord({
            lender: commitment.lender,
            // bounded by _validateAndReserve
            // forge-lint: disable-next-line(unsafe-typecast)
            commitmentId: uint88(_commitmentId),
            accepted: false,
            principal: _principalAmount
        });

        emit BidStaged(bidId, _commitmentId, borrower, _principalAmount);
    }

    /**
     * @notice Step 2: accept a staged bid on behalf of the commitment's lender.
     * Permissionless: the lender pre-authorised these terms by creating the
     * commitment and approving this forwarder. Reverts on TellerV2 if the bid
     * is no longer pending or has expired, or if the lender or borrower has
     * renounced this forwarder.
     * @param _bidId The TellerV2 bid id returned by {submitStagedCommitmentBid}.
     * @return amountToProtocol Protocol fee paid by the lender.
     * @return amountToMarketplace Marketplace fee paid by the lender.
     * @return amountToBorrower Principal sent to the bid's receiver.
     */
    function acceptStagedCommitmentBid(uint256 _bidId)
        external
        returns (
            uint256 amountToProtocol,
            uint256 amountToMarketplace,
            uint256 amountToBorrower
        )
    {
        StagedBidRecord storage staged = _stagedBids[_bidId];
        address lender = staged.lender;
        uint256 commitmentId = staged.commitmentId;

        require(lender != address(0), "bid not staged");
        require(!staged.accepted, "bid already accepted");
        if (CHECK_LENDER_ON_ACCEPT) {
            require(
                ALPHA.getCommitmentLender(commitmentId) == lender,
                "commitment lender changed"
            );
        }

        staged.accepted = true;

        // Same call as _acceptBid, keeping TellerV2's return values.
        bytes memory responseData = _forwardCall(
            abi.encodeWithSelector(ITellerV2.lenderAcceptBid.selector, _bidId),
            lender
        );
        (amountToProtocol, amountToMarketplace, amountToBorrower) = abi.decode(
            responseData,
            (uint256, uint256, uint256)
        );

        emit StagedBidAccepted(_bidId, commitmentId, lender);
    }

    /**
     * @notice Release a staged bid that was never accepted through this
     * forwarder, once TellerV2 reports it is no longer pending (cancelled, or
     * accepted elsewhere) or has expired. Returns its principal to the
     * commitment. Callable by anyone.
     * @param _bidId The TellerV2 bid id.
     */
    function releaseStagedBid(uint256 _bidId) external {
        StagedBidRecord memory staged = _stagedBids[_bidId];

        require(staged.lender != address(0), "bid not staged");
        require(!staged.accepted, "bid already accepted");

        ITellerV2BidStatus tellerV2 = ITellerV2BidStatus(_tellerV2);
        require(
            tellerV2.getBidState(_bidId) != BidState.PENDING ||
                tellerV2.isLoanExpired(_bidId),
            "bid still pending"
        );

        stagedPrincipal[staged.commitmentId] -= staged.principal;
        delete _stagedBids[_bidId];

        emit StagedBidReleased(_bidId, staged.commitmentId);
    }

    /**
     * @dev Alpha's `_acceptCommitment` checks for an ERC20-collateral,
     * statically priced commitment, with the principal budget shared between
     * Alpha's accepted principal and {stagedPrincipal}. Reserves the principal
     * (before any call out to TellerV2) and returns the commitment.
     */
    function _validateAndReserve(
        uint256 _commitmentId,
        uint256 _principalAmount,
        uint256 _collateralAmount,
        address _collateralTokenAddress,
        uint16 _interestRate,
        uint32 _loanDuration,
        address _borrower
    )
        internal
        returns (ILenderCommitmentForwarder_U1.Commitment memory commitment)
    {
        commitment = ALPHA.commitments(_commitmentId);

        require(commitment.lender != address(0), "unknown commitment");
        require(
            commitment.collateralTokenType ==
                ILenderCommitmentForwarder_U1.CommitmentCollateralType.ERC20,
            "Invalid commitment collateral type"
        );
        require(
            ALPHA.getAllCommitmentUniswapPoolRoutes(_commitmentId).length == 0,
            "oracle-priced commitment"
        );
        require(_commitmentId <= type(uint88).max, "commitment id too large");

        // Alpha's validateCommitment, for ERC20 collateral
        require(
            commitment.expiration > uint32(block.timestamp),
            "expired commitment"
        );
        require(
            commitment.maxPrincipal > 0,
            "commitment principal allocation 0"
        );
        require(
            commitment.maxPrincipalPerCollateralAmount > 0,
            "commitment collateral ratio 0"
        );
        require(
            commitment.collateralTokenId == 0,
            "commitment collateral token id must be 0 for ERC20"
        );

        require(
            _collateralTokenAddress == commitment.collateralTokenAddress,
            "Mismatching collateral token"
        );
        require(
            _interestRate >= commitment.minInterestRate,
            "Invalid interest rate"
        );
        require(
            _loanDuration <= commitment.maxDuration,
            "Invalid loan max duration"
        );
        require(
            _isAllowedBorrower(_commitmentId, _borrower),
            "unauthorized commitment borrower"
        );

        if (_principalAmount > commitment.maxPrincipal) {
            revert InsufficientCommitmentAllocation({
                allocated: commitment.maxPrincipal,
                requested: _principalAmount
            });
        }

        {
            uint256 requiredCollateral = MathUpgradeable.mulDiv(
                _principalAmount,
                STANDARD_EXPANSION_FACTOR,
                commitment.maxPrincipalPerCollateralAmount,
                MathUpgradeable.Rounding.Up
            );
            if (_collateralAmount < requiredCollateral) {
                revert InsufficientBorrowerCollateral({
                    required: requiredCollateral,
                    actual: _collateralAmount
                });
            }
        }

        uint256 reserved = stagedPrincipal[_commitmentId] + _principalAmount;
        require(
            ALPHA.getCommitmentAcceptedPrincipal(_commitmentId) + reserved <=
                commitment.maxPrincipal,
            "Exceeds max principal of commitment"
        );
        stagedPrincipal[_commitmentId] = reserved;
    }

    function _isAllowedBorrower(uint256 _commitmentId, address _borrower)
        internal
        view
        returns (bool)
    {
        address[] memory borrowers = ALPHA.getCommitmentBorrowers(
            _commitmentId
        );
        if (borrowers.length == 0) return true;
        for (uint256 i = 0; i < borrowers.length; i++) {
            if (borrowers[i] == _borrower) return true;
        }
        return false;
    }
}
