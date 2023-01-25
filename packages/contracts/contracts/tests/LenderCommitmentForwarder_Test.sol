// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@mangrovedao/hardhat-test-solidity/test.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../TellerV2MarketForwarder.sol";
import "../TellerV2Context.sol";
import { Testable } from "./Testable.sol";
import { LenderCommitmentForwarder } from "../LenderCommitmentForwarder.sol";

import {
    Collateral,
    CollateralType
} from "../interfaces/escrow/ICollateralEscrowV1.sol";

contract LenderCommitmentForwarder_Test is Testable, LenderCommitmentForwarder {
    LenderCommitmentTester private tester;
    MockMarketRegistry mockMarketRegistry;

    User private marketOwner;
    User private lender;
    User private borrower;

    address tokenAddress;
    uint256 marketId;
    uint256 maxAmount;

    address collateralTokenAddress;
    uint256 maxPrincipalPerCollateralAmount;
    CollateralType collateralTokenType;

    uint32 maxLoanDuration;
    uint16 minInterestRate;
    uint32 expiration;

    bool acceptBidWasCalled;
    bool submitBidWasCalled;
    bool submitBidWithCollateralWasCalled;

    constructor()
        LenderCommitmentForwarder(
            address(new LenderCommitmentTester()),
            address(new MockMarketRegistry(address(0)))
        )
    {}

    function setup_beforeAll() public {
        tester = LenderCommitmentTester(address(getTellerV2()));
        mockMarketRegistry = MockMarketRegistry(address(getMarketRegistry()));

        marketOwner = new User(tester, (this));
        borrower = new User(tester, (this));
        lender = new User(tester, (this));
        tester.__setMarketOwner(marketOwner);

        mockMarketRegistry.setMarketOwner(address(marketOwner));

        tokenAddress = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        marketId = 2;
        maxAmount = 100000000000000000000;
        maxLoanDuration = 2480000;
        minInterestRate = 3000;
        expiration = uint32(block.timestamp) + uint32(64000);

        collateralTokenAddress = address(
            0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174
        );
        maxPrincipalPerCollateralAmount = 10000;
        collateralTokenType = CollateralType.ERC20;

        marketOwner.setTrustedMarketForwarder(marketId, address(this));
        lender.approveMarketForwarder(marketId, address(this));

        delete acceptBidWasCalled;
        delete submitBidWasCalled;
    }

    function updateCommitment_before() public {
        uint256 commitmentId = lender._createCommitment(
            marketId,
            tokenAddress,
            maxAmount,
            collateralTokenAddress,
            maxPrincipalPerCollateralAmount,
            collateralTokenType,
            maxLoanDuration,
            minInterestRate,
            expiration
        );

        console.log(commitmentId);
    }

    function updateCommitment_test() public {

        uint256 commitmentId = 0;

        Commitment memory existingCommitment = lenderMarketCommitments[commitmentId];

        Test.eq(address(lender), existingCommitment.lender,"Not the owner of created commitment");

        lender._updateCommitment(
            commitmentId,
            marketId,
            tokenAddress,
            maxAmount,
            collateralTokenAddress,
            maxPrincipalPerCollateralAmount,
            collateralTokenType,
            maxLoanDuration,
            minInterestRate,
            expiration
            );



    }

    function deleteCommitment_test() public {
        //make sure the commitment exists
        //Test.eq( ,  ,"" );
        //        super.deleteCommitment(tokenAddress, marketId);
        //        Commitment memory existingCommitment = lenderMarketCommitments[address(this)][marketId][tokenAddress];
        //make sure the commitment has been removed
        //Test.eq( ,  ,"" );
    }

    function acceptCommitment_before() public {
        
         lender._createCommitment(
            marketId,
            tokenAddress,
            maxAmount,
            collateralTokenAddress,
            maxPrincipalPerCollateralAmount,
            collateralTokenType,
            maxLoanDuration,
            minInterestRate,
            expiration
        );
    }

    function acceptCommitment_test() public {

        uint256 commitmentId = 0;

        Commitment storage commitment = lenderMarketCommitments[commitmentId];

        Test.eq(
            acceptBidWasCalled,
            false,
            "Expect accept bid not called before exercise"
        );

        uint256 bidId = marketOwner._acceptCommitment(
            commitmentId,
            marketId,
            
           
            maxAmount - 100,
            maxAmount, //collateralAmount
            0, //collateralTokenId
            maxLoanDuration,
            minInterestRate
        );

        Test.eq(
            acceptBidWasCalled,
            true,
            "Expect accept bid called after exercise"
        );

        Test.eq(
            commitment.maxPrincipal == 100,
            true,
            "commitment not accepted"
        );

        bidId = marketOwner._acceptCommitment(
            commitmentId,
            marketId,
            
            100,
            100, //collateralAmount
            0, //collateralTokenId
            maxLoanDuration,
            minInterestRate
        );

        Test.eq(commitment.maxPrincipal == 0, true, "commitment not accepted");
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

        Test.eq(
            submitBidWithCollateralWasCalled,
            true,
            "Submit bid must be called before accept bid"
        );

        return true;
    }
}

contract User {
    TellerV2Context public immutable context;
    LenderCommitmentForwarder public immutable commitmentForwarder;

    constructor(
        TellerV2Context _context,
        LenderCommitmentForwarder _commitmentForwarder
    ) {
        context = _context;
        commitmentForwarder = _commitmentForwarder;
    }

    function setTrustedMarketForwarder(uint256 _marketId, address _forwarder)
        external
    {
        context.setTrustedMarketForwarder(_marketId, _forwarder);
    }

    function approveMarketForwarder(uint256 _marketId, address _forwarder)
        external
    {
        context.approveMarketForwarder(_marketId, _forwarder);
    }

    function _createCommitment(
        uint256 marketId,
        address tokenAddress,
        uint256 principal,
        address _collateralTokenAddress,
        uint256 _maxPrincipalPerCollateralAmount,
        CollateralType _collateralTokenType,
        uint32 loanDuration,
        uint16 interestRate,
        uint32 expiration
    ) public returns (uint256) {
        return commitmentForwarder.createCommitment(
            marketId,
            tokenAddress,
            principal,
            _collateralTokenAddress,
            _maxPrincipalPerCollateralAmount,
            _collateralTokenType,
            loanDuration,
            interestRate,
            expiration
        );
    }

    function _updateCommitment(
        uint256 commitmentId,
        uint256 marketId,
        address tokenAddress,
        uint256 principal,
        address _collateralTokenAddress,
        uint256 _maxPrincipalPerCollateralAmount,
        CollateralType _collateralTokenType,
        uint32 loanDuration,
     
        uint16 interestRate,
           uint32 expiration
    ) public {
        commitmentForwarder.updateCommitment(
            commitmentId,
            marketId,
            tokenAddress,
            principal,
            _collateralTokenAddress,
            _maxPrincipalPerCollateralAmount,
            _collateralTokenType,
            loanDuration,
            interestRate,
            expiration
        );
    }

    function _acceptCommitment(
        uint256  commitmentId,
        uint256 marketId,
        
         
        uint256 principal,
        uint256 collateralAmount,
        uint256 collateralTokenId,
        uint32 loanDuration,
        uint16 interestRate
    ) public returns (uint256) {
        return
            commitmentForwarder.acceptCommitment(
                commitmentId,
                marketId,         
                principal,
                collateralAmount,
                collateralTokenId,
                loanDuration,
                interestRate
            );
    }
}

contract LenderCommitmentTester is TellerV2Context {
    constructor() TellerV2Context(address(0)) {}

    function __setMarketOwner(User _marketOwner) external {
        marketRegistry = IMarketRegistry(
            address(new MockMarketRegistry(address(_marketOwner)))
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

contract MockMarketRegistry {
    address private marketOwner;

    constructor(address _marketOwner) {
        marketOwner = _marketOwner;
    }

    function setMarketOwner(address _marketOwner) public {
        marketOwner = _marketOwner;
    }

    function getMarketOwner(uint256) external view returns (address) {
        return address(marketOwner);
    }
}
