// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/TellerV2MarketForwarder.sol";

import "./resolvers/TestERC20Token.sol";
import "../contracts/TellerV2Context.sol";

import { Testable } from "./Testable.sol";
import { LenderCommitmentForwarder } from "../contracts/LenderCommitmentForwarder.sol";

import { Collateral, CollateralType } from "../contracts/interfaces/escrow/ICollateralEscrowV1.sol";

import { User } from "./Test_Helpers.sol";

import "../contracts/mock/MarketRegistryMock.sol";
import "../contracts/mock/AllowlistManagerMock.sol";

contract EnumerableSetAllowlist_Test is Testable, LenderCommitmentForwarder {
    LenderCommitmentForwarderTest_TellerV2Mock private tellerV2Mock;
    MarketRegistryMock mockMarketRegistry;

    LenderCommitmentUser private marketOwner;
    LenderCommitmentUser private lender;
    LenderCommitmentUser private borrower;

    //  address tokenAddress;
    uint256 marketId;
    uint256 maxAmount;

    address[] emptyArray;
    address[] borrowersArray;

    uint32 maxLoanDuration;
    uint16 minInterestRate;
    uint32 expiration;

    bool acceptBidWasCalled;
    bool submitBidWasCalled;
    bool submitBidWithCollateralWasCalled;

    AllowlistManagerMock allowlistManager; 

    TestERC20Token principalToken;
    uint8 constant principalTokenDecimals = 18;

    TestERC20Token collateralToken;
    uint8 constant collateralTokenDecimals = 6;

    constructor()
        LenderCommitmentForwarder(
            address(new LenderCommitmentForwarderTest_TellerV2Mock()), ///_protocolAddress
            address(new MarketRegistryMock(address(0)))
        )
    {}

    function setUp() public {
        tellerV2Mock = LenderCommitmentForwarderTest_TellerV2Mock(
            address(getTellerV2())
        );
        mockMarketRegistry = MarketRegistryMock(address(getMarketRegistry()));

        allowlistManager = new AllowlistManagerMock();

        marketOwner = new LenderCommitmentUser(address(tellerV2Mock), (this), address(allowlistManager));
        borrower = new LenderCommitmentUser(address(tellerV2Mock), (this), address(allowlistManager));
        lender = new LenderCommitmentUser(address(tellerV2Mock), (this), address(allowlistManager));
        tellerV2Mock.__setMarketOwner(marketOwner);

        mockMarketRegistry.setMarketOwner(address(marketOwner));
      

        //tokenAddress = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        marketId = 2;
        maxAmount = 100000000000000000000;
        maxLoanDuration = 2480000;
        minInterestRate = 3000;
        expiration = uint32(block.timestamp) + uint32(64000);

        marketOwner.setTrustedMarketForwarder(marketId, address(this));
        lender.approveMarketForwarder(marketId, address(this));

        borrowersArray = new address[](1);
        borrowersArray[0] = address(borrower);

        principalToken = new TestERC20Token(
            "Test Wrapped ETH",
            "TWETH",
            0,
            principalTokenDecimals
        );

        collateralToken = new TestERC20Token(
            "Test USDC",
            "TUSDC",
            0,
            collateralTokenDecimals
        );

        delete acceptBidWasCalled;
        delete submitBidWasCalled;
        delete submitBidWithCollateralWasCalled;

        delete commitmentCount;
    }

    function _createCommitment(
        CommitmentCollateralType _collateralType,
        uint256 _maxPrincipalPerCollateral
    ) internal returns (Commitment storage commitment_) {
        commitment_ = commitments[0];
        commitment_.marketId = marketId;
        commitment_.principalTokenAddress = address(principalToken);
        commitment_.maxPrincipal = maxAmount;
        commitment_.maxDuration = maxLoanDuration;
        commitment_.minInterestRate = minInterestRate;
        commitment_.expiration = expiration;
        commitment_.lender = address(lender);

        commitment_.collateralTokenType = _collateralType;
        commitment_.maxPrincipalPerCollateralAmount =
            _maxPrincipalPerCollateral *
            10**principalTokenDecimals;

        if (_collateralType == CommitmentCollateralType.ERC20) {
            commitment_.collateralTokenAddress = address(collateralToken);
        } else if (_collateralType == CommitmentCollateralType.ERC721) {
            commitment_.collateralTokenAddress = address(
                0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174
            );
        } else if (_collateralType == CommitmentCollateralType.ERC1155) {
            commitment_.collateralTokenAddress = address(
                0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174
            );
        }
    }

    function test_createCommitment() public {
        uint256 commitmentId = 0;

        Commitment storage existingCommitment = _createCommitment(
            CommitmentCollateralType.ERC20,
            1000e6 * 1e18
        );

        lender._createCommitment(existingCommitment, emptyArray);
    }

    function test_updateCommitment() public {
        uint256 commitmentId = 0;

        Commitment storage existingCommitment = _createCommitment(
            CommitmentCollateralType.ERC20,
            1000e6
        );

        assertEq(
            address(lender),
            existingCommitment.lender,
            "Not the owner of created commitment"
        );

        lender._updateCommitment(commitmentId, existingCommitment);
    }

    function test_deleteCommitment() public {
        uint256 commitmentId = 0;
        Commitment storage commitment = _createCommitment(
            CommitmentCollateralType.ERC20,
            1000e6
        );

        assertEq(
            commitment.lender,
            address(lender),
            "Not the owner of created commitment"
        );

        lender._deleteCommitment(commitmentId);

        assertEq(
            commitment.lender,
            address(0),
            "The commitment was not deleted"
        );
    }

    function test_acceptCommitment() public {
        uint256 commitmentId = 0;

        Commitment storage commitment = _createCommitment(
            CommitmentCollateralType.ERC20,
            maxAmount
        );

        assertEq(
            acceptBidWasCalled,
            false,
            "Expect accept bid not called before exercise"
        );

        uint256 bidId = borrower._acceptCommitment(
            commitmentId,
            maxAmount - 100, //principal
            maxAmount, //collateralAmount
            0, //collateralTokenId
            address(collateralToken),
            minInterestRate,
            maxLoanDuration
        );

        assertEq(
            acceptBidWasCalled,
            true,
            "Expect accept bid called after exercise"
        );

        assertEq(
            commitment.maxPrincipal == 100,
            true,
            "Commitment max principal was not decremented"
        );

        bidId = borrower._acceptCommitment(
            commitmentId,
            100, //principalAmount
            100, //collateralAmount
            0, //collateralTokenId
            address(collateralToken),
            minInterestRate,
            maxLoanDuration
        );

        assertEq(commitment.maxPrincipal == 0, true, "commitment not accepted");

        bool acceptCommitTwiceFails;

        try
            borrower._acceptCommitment(
                commitmentId,
                100, //principalAmount
                100, //collateralAmount
                0, //collateralTokenId
                address(collateralToken),
                minInterestRate,
                maxLoanDuration
            )
        {} catch {
            acceptCommitTwiceFails = true;
        }

        assertEq(
            acceptCommitTwiceFails,
            true,
            "Should fail when accepting commit twice"
        );
    }

 /*   function test_acceptCommitmentWithBorrowersArray_valid() public {
        uint256 commitmentId = 0;

        Commitment storage commitment = _createCommitment(
            CommitmentCollateralType.ERC20,
            maxAmount
        );

        lender._updateCommitmentBorrowers(commitmentId, borrowersArray);

        uint256 bidId = borrower._acceptCommitment(
            commitmentId,
            0, //principal
            maxAmount, //collateralAmount
            0, //collateralTokenId
            address(collateralToken),
            minInterestRate,
            maxLoanDuration
        );

        assertEq(
            acceptBidWasCalled,
            true,
            "Expect accept bid called after exercise"
        );
    }

    function test_acceptCommitmentWithBorrowersArray_invalid() public {
        uint256 commitmentId = 0;

        Commitment storage commitment = _createCommitment(
            CommitmentCollateralType.ERC20,
            maxAmount
        );

        lender._updateCommitmentBorrowers(commitmentId, borrowersArray);

        bool acceptCommitAsMarketOwnerFails;

        try
            marketOwner._acceptCommitment(
                commitmentId,
                100, //principal
                maxAmount, //collateralAmount
                0, //collateralTokenId
                address(collateralToken),
                minInterestRate,
                maxLoanDuration
            )
        {} catch {
            acceptCommitAsMarketOwnerFails = true;
        }

        assertEq(
            acceptCommitAsMarketOwnerFails,
            true,
            "Should fail when accepting as invalid borrower"
        );

        lender._updateCommitmentBorrowers(commitmentId, emptyArray);

        acceptBidWasCalled = false;

        marketOwner._acceptCommitment(
            commitmentId,
            0, //principal
            maxAmount, //collateralAmount
            0, //collateralTokenId
            address(collateralToken),
            minInterestRate,
            maxLoanDuration
        );

        assertEq(
            acceptBidWasCalled,
            true,
            "Expect accept bid called after exercise"
        );
    }

    function test_acceptCommitmentWithBorrowersArray_reset() public {
        uint256 commitmentId = 0;

        Commitment storage commitment = _createCommitment(
            CommitmentCollateralType.ERC20,
            maxAmount
        );

        lender._updateCommitmentBorrowers(commitmentId, borrowersArray);

        lender._updateCommitmentBorrowers(commitmentId, emptyArray);

        marketOwner._acceptCommitment(
            commitmentId,
            0, //principal
            maxAmount, //collateralAmount
            0, //collateralTokenId
            address(collateralToken),
            minInterestRate,
            maxLoanDuration
        );

        assertEq(
            acceptBidWasCalled,
            true,
            "Expect accept bid called after exercise"
        );
    }*/

    function test_acceptCommitmentFailsWithInsufficientCollateral() public {
        uint256 commitmentId = 0;

        Commitment storage commitment = _createCommitment(
            CommitmentCollateralType.ERC20,
            1000e6
        );

        bool failedToAcceptCommitment;

        try
            marketOwner._acceptCommitment(
                commitmentId,
                100, //principal
                0, //collateralAmount
                0, //collateralTokenId
                address(collateralToken),
                minInterestRate,
                maxLoanDuration
            )
        {} catch {
            failedToAcceptCommitment = true;
        }

        assertEq(
            failedToAcceptCommitment,
            true,
            "Should fail to accept commitment with insufficient collateral"
        );
    }

    function test_acceptCommitmentFailsWithInvalidAmount() public {
        uint256 commitmentId = 0;

        Commitment storage commitment = _createCommitment(
            CommitmentCollateralType.ERC721,
            1000e6
        );

        bool failedToAcceptCommitment;

        try
            marketOwner._acceptCommitment(
                commitmentId,
                100, //principal
                2, //collateralAmount
                22, //collateralTokenId
                address(collateralToken),
                minInterestRate,
                maxLoanDuration
            )
        {} catch {
            failedToAcceptCommitment = true;
        }

        assertEq(
            failedToAcceptCommitment,
            true,
            "Should fail to accept commitment with invalid amount for ERC721"
        );
    }

    function decrementCommitment_before() public {}

    function test_decrementCommitment() public {
        uint256 commitmentId = 0;
        uint256 _decrementAmount = 22;

        Commitment storage commitment = _createCommitment(
            CommitmentCollateralType.ERC20,
            1000e6
        );

        _decrementCommitment(commitmentId, _decrementAmount);

        assertEq(
            commitment.maxPrincipal == maxAmount - _decrementAmount,
            true,
            "Commitment max principal was not decremented"
        );
    }

    /**
     *             collateral token = WETH (10**18)
     *              principal token = USDC (10**6)
     *                    principal = 700 USDC
     * max principal per collateral = 500 USDC
     */

    function test_getRequiredCollateral_700_USDC__500_per_WETH() public {
        TestERC20Token usdcToken = new TestERC20Token(
            "Test USDC",
            "TUSDC",
            0,
            6
        );

        TestERC20Token collateralToken = new TestERC20Token(
            "Test Wrapped ETH",
            "TWETH",
            0,
            18
        );
        assertEq(
            super.getRequiredCollateral(
                700 * (1e6), // 700 USDC loan
                500 * (1e6) * (1e6), // 500 USDC loan allowed per WETH, expanded by principal token decimals
                CommitmentCollateralType.ERC20,
                address(collateralToken),
                address(usdcToken)
            ),
            14e17, // 1.4 WETH
            "expected 1.4 WETH collateral"
        );
    }

    /**
     *             collateral token = NFT (10**0)
     *              principal token = USDC (10**6)
     *                    principal = 700 USDC
     * max principal per collateral = 500 USDC
     */
    function test_getRequiredCollateral_700_USDC_loan__500_per_ERC1155()
        public
    {
        TestERC20Token usdcToken = new TestERC20Token(
            "Test USDC",
            "TUSDC",
            0,
            6
        );

        assertEq(
            super.getRequiredCollateral(
                700e6, // 700 USDC loan
                500e6 * (10**6) * (10**0), // 500 USDC per NFT
                CommitmentCollateralType.ERC1155,
                address(0),
                address(usdcToken)
            ),
            2, // 2 NFTs
            "expected 2 NFTs collateral"
        );
    }

    /**
     *             collateral token = NFT (10**0)
     *              principal token = USDC (10**6)
     *                    principal = 500 USDC
     * max principal per collateral = 500 USDC
     */

    function test_getRequiredCollateral_500_USDC_loan__500_per_ERC721() public {
        TestERC20Token usdcToken = new TestERC20Token(
            "Test USDC",
            "TUSDC",
            0,
            6
        );

        assertEq(
            super.getRequiredCollateral(
                500e6, // 7500 USDC loan
                500e6 * (1e6), // 500 USDC per NFT, expanded by principal token decimals
                CommitmentCollateralType.ERC721,
                address(0),
                address(usdcToken)
            ),
            1, // 1 NFT
            "expected 1 NFT collateral"
        );
    }

    /**
     *             collateral token = USDC (10**6)
     *              principal token = WETH (10**18)
     *                    principal = 1 WETH
     * max principal per collateral = 0.00059 WETH
     */
    function test_getRequiredCollateral_1_WETH_loan__00059_per_USDC() public {
        TestERC20Token collateralToken = new TestERC20Token(
            "Test USDC",
            "TUSDC",
            0,
            6
        );
        assertEq(
            super.getRequiredCollateral(
                1e18, // 1 WETH loan
                59e13 * (1e18), // 0.00059 WETH per USDC base unit
                CommitmentCollateralType.ERC20,
                address(collateralToken),
                address(principalToken)
            ),
            1_694_915_255, // 1,694.915255 USDC (1694.915254237 rounded up to 6 decimals)
            "expected 1,694.915255 USDC collateral"
        );
    }

    /**
     *             collateral token = WETH (10**18)
     *              principal token = USDC (10**6)
     *                    principal = 1000 USDC $
     * max principal per collateral = 1.0 WETH
     */

    function test_getRequiredCollateral_1000_USDC_loan_9_gwei_per_usdc_unit()
        public
    {
        TestERC20Token usdcToken = new TestERC20Token(
            "Test USDC",
            "TUSDC",
            0,
            6
        );

        TestERC20Token collateralToken = new TestERC20Token(
            "Test WETH",
            "TWETH",
            0,
            18
        );

        assertEq(
            super.getRequiredCollateral(
                1000 * (1e6), // 1000 USDC loan  //principal
                1e9 * (1e6), // 1000000000 wei  per USDC base unit   //ratio
                CommitmentCollateralType.ERC20,
                address(collateralToken),
                address(usdcToken)
            ),
            1e18, // 1 wETH
            "expected 1 ETH required collateral"
        );
    }

    /**
     *             collateral token = WETH (10**18)
     *              principal token = USDC (10**6)
     *                    principal = 8888 USDC $
     * max principal per collateral = 1 gwei per USDDC base unit
     */

    function test_getRequiredCollateral_8888_USDC_loan__9_gwei_per_usdc_unit()
        public
    {
        TestERC20Token usdcToken = new TestERC20Token(
            "Test USDC",
            "TUSDC",
            0,
            6
        );

        TestERC20Token collateralToken = new TestERC20Token(
            "Test WETH",
            "TWETH",
            0,
            18
        );

        assertEq(
            super.getRequiredCollateral(
                8888 * (1e6), // 8888 USDC loan  //principal
                1e9 * (1e6), // 1000000000 wei  per USDC base unit   //ratio
                CommitmentCollateralType.ERC20,
                address(collateralToken),
                address(usdcToken)
            ),
            8888e15, // 8.888 wETH
            "expected 1 ETH required collateral"
        );
    }

    /**
     *             collateral token = WETH (10**18)
     *              principal token = USDC (10**8)
     *                    principal = 8888 USDC
     * max principal per collateral =  8888000000 wei per USDC base unit
     */
    function test_getRequiredCollateral_8888_USDC_loan__unit() public {
        TestERC20Token usdcToken = new TestERC20Token(
            "Test USDC",
            "TUSDC",
            0,
            6
        );

        TestERC20Token collateralToken = new TestERC20Token(
            "Test WETH",
            "TWETH",
            0,
            18
        );

        assertEq(
            super.getRequiredCollateral(
                8888 * (1e6), // 8888 USDC loan  //principal
                8888000000 * (1e6), // 8888000000 wei  per USDC base unit
                CommitmentCollateralType.ERC20,
                address(collateralToken),
                address(usdcToken)
            ),
            1e18, // 1 wETH
            "expected 1 ETH required collateral"
        );
    }

    /**
     *             collateral token = USDC (10**6)
     *              principal token = GWEI (10**9)
     *                    principal = 6 GWEI
     * max principal per collateral = 0.00059 USDC per gwei
     */
    function test_getRequiredCollateral_6_GWEI_loan__00059_WETH_per_USDC()
        public
    {
        TestERC20Token gweiToken = new TestERC20Token(
            "Test USDC",
            "TUSDC",
            0,
            9
        );

        TestERC20Token collateralToken = new TestERC20Token(
            "Test USDC",
            "TUSDC",
            0,
            6
        );
        assertEq(
            super.getRequiredCollateral(
                6 gwei, // 6 GWEI loan
                59e13 * (1e9), // 0.00059 USDC per gwei
                CommitmentCollateralType.ERC20,
                address(collateralToken),
                address(gweiToken)
            ),
            11, // 0.000011 USDC (0.000010169 rounded up to 6 decimals)
            "expected 0.000011 USDC collateral"
        );
    }

    /**
     *             collateral token = USDC (10**6)
     *              principal token = WEI (10**0)
     *                    principal = 1 WEI
     * max principal per collateral = // 0.00059 WETH per usdc base unit
     */
    function test_getRequiredCollateral_1_WEI_loan__00059_WETH_per_USDC()
        public
    {
        TestERC20Token collateralToken = new TestERC20Token(
            "Test USDC",
            "TUSDC",
            0,
            6
        );
        assertEq(
            super.getRequiredCollateral(
                1, // 1 WEI loan
                59e13 * 1e18, // 0.00059 WETH per USDC base unit
                CommitmentCollateralType.ERC20,
                address(collateralToken),
                address(principalToken)
            ),
            1, // 0.001695 USDC rounded up
            "expected at least 1 unit of collateral"
        );
    }

    /**
     *             collateral token = USDC (10**6)
     *              principal token = WETH (10**18)
     *                    principal = 1 GWEI
     * max principal per collateral = 0.00059 WETH per gwei
     */
    function test_getRequiredCollateral_1_GWEI_loan__00059_WETH_per_USDC()
        public
    {
        TestERC20Token collateralToken = new TestERC20Token(
            "Test USDC",
            "TUSDC",
            0,
            6
        );
        assertEq(
            super.getRequiredCollateral(
                1e9, // 1 GWEI loan
                59e13 * 1e18, // 0.00059 WETH per USDC base unit (hence why not multiplying by 1e6)
                CommitmentCollateralType.ERC20,
                address(collateralToken),
                address(principalToken)
            ),
            2,
            "expected at least 2 units of collateral"
        );
    }

    /**
     *             collateral token = USDC (10**6)
     *              principal token = WETH (10**18)
     *                    principal = 1 GWEI
     * max principal per collateral = 1 wei per usdc $
     */
    function test_getRequiredCollateral_1_wei_loan__1_Wei_per_USDC() public {
        TestERC20Token collateralToken = new TestERC20Token(
            "Test USDC",
            "TUSDC",
            0,
            6
        );
        assertEq(
            super.getRequiredCollateral(
                1e9, // 1 gwei
                (1 * 1e6) * 1e18, // must provide 1:1 ratio usdc $ to wei
                CommitmentCollateralType.ERC20,
                address(collateralToken),
                address(principalToken)
            ),
            1e3 * 1e6, // 1000 usdc $
            "expected at least 1 unit of collateral"
        );
    }

    /**
     *             collateral token = USDC (10**6)
     *              principal token = WETH (10**18)
     *                    principal = 1 wei
     * max principal per collateral = 1 wei per usdc $
     */
    function test_getRequiredCollateral_1_wei_loan__1_Wei_per_USDC_unit()
        public
    {
        TestERC20Token collateralToken = new TestERC20Token(
            "Test USDC",
            "TUSDC",
            0,
            6
        );
        assertEq(
            super.getRequiredCollateral(
                1, // 1 wei
                (1 * 1e6) * 1e18, // must provide 1 usdc to get loan of 1 wei, expanded by principal decimals
                CommitmentCollateralType.ERC20,
                address(collateralToken),
                address(principalToken)
            ),
            1, // 1 usdc base unit
            "expected at least 1 unit of collateral"
        );
    }

    /*
        Overrider methods for exercise 
    */

    function _submitBid(CreateLoanArgs memory, address)
        internal
        override
        returns (uint256 bidId)
    {
        submitBidWasCalled = true;
        return 1;
    }

    function _submitBidWithCollateral(
        CreateLoanArgs memory,
        Collateral[] memory,
        address
    ) internal override returns (uint256 bidId) {
        submitBidWithCollateralWasCalled = true;
        return 1;
    }

    function _acceptBid(uint256, address) internal override returns (bool) {
        acceptBidWasCalled = true;

        assertEq(
            submitBidWithCollateralWasCalled,
            true,
            "Submit bid must be called before accept bid"
        );

        return true;
    }
}

contract LenderCommitmentUser is User {
    LenderCommitmentForwarder public immutable commitmentForwarder;
    AllowlistManagerMock allowlistManager;

    constructor(
        address _tellerV2,
        LenderCommitmentForwarder _commitmentForwarder,
        address _allowlistManager
    ) User(_tellerV2) {
        commitmentForwarder = _commitmentForwarder;
        allowlistManager = AllowlistManagerMock(_allowlistManager);
    }

    function _createCommitment(
        LenderCommitmentForwarder.Commitment calldata _commitment,
        address[] calldata borrowerAddressList
    ) public returns (uint256) {
        return
            commitmentForwarder.createCommitment(
                _commitment,
                address(allowlistManager)
            );
    }

    function _updateCommitment(
        uint256 commitmentId,
        LenderCommitmentForwarder.Commitment calldata _commitment
    ) public {
        commitmentForwarder.updateCommitment(commitmentId, _commitment);
    }

    function _updateCommitmentBorrowers(
        uint256 commitmentId,
        address[] calldata borrowerAddressList
    ) public {
        commitmentForwarder.updateCommitmentBorrowers(
            commitmentId,
            borrowerAddressList
        );
    }

    function _acceptCommitment(
        uint256 commitmentId,
        uint256 principal,
        uint256 collateralAmount,
        uint256 collateralTokenId,
        address collateralTokenAddress,
        uint16 interestRate,
        uint32 loanDuration
    ) public returns (uint256) {
        return
            commitmentForwarder.acceptCommitment(
                commitmentId,
                principal,
                collateralAmount,
                collateralTokenId,
                collateralTokenAddress,
                interestRate,
                loanDuration
            );
    }

    function _deleteCommitment(uint256 _commitmentId) public {
        commitmentForwarder.deleteCommitment(_commitmentId);
    }
}

//Move to a helper file !
contract LenderCommitmentForwarderTest_TellerV2Mock is TellerV2Context {
    constructor() TellerV2Context(address(0)) {}

    function __setMarketOwner(User _marketOwner) external {
        marketRegistry = IMarketRegistry(
            address(new MarketRegistryMock(address(_marketOwner)))
        );
    }

    function getSenderForMarket(uint256 _marketId)
        external
        view
        returns (address)
    {
        return _msgSenderForMarket(_marketId);
    }

    function getDataForMarket(uint256 _marketId)
        external
        view
        returns (bytes calldata)
    {
        return _msgDataForMarket(_marketId);
    }
}
