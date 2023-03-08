// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/TellerV2MarketForwarder.sol";

import "./resolvers/TestERC20Token.sol";
import "../contracts/TellerV2Context.sol";

import { Testable } from "./Testable.sol";
 
import { Collateral, CollateralType } from "../contracts/interfaces/escrow/ICollateralEscrowV1.sol";

import { User } from "./Test_Helpers.sol";

import "../contracts/mock/MarketRegistryMock.sol";
import "../contracts/mock/CollateralManagerMock.sol";

import "../contracts/MarketLiquidityRewards.sol";

contract MarketLiquidityRewards_Test is Testable, MarketLiquidityRewards {
    TellerV2Mock private tellerV2Mock;
    MarketRegistryMock mockMarketRegistry;
    CollateralManagerMock mockCollateralManager;
    MarketLiquidityRewards marketLiquidityRewards;

    MarketLiquidityUser private marketOwner;
    MarketLiquidityUser private lender;
    MarketLiquidityUser private borrower;



    uint256 immutable startTime = 1678122531;



    //  address tokenAddress;
    uint256 marketId;
    uint256 maxAmount;

    address[] emptyArray;
    address[] borrowersArray;

    uint32 maxLoanDuration;
    uint16 minInterestRate;
    uint32 expiration;
    


   
    TestERC20Token rewardToken;
    uint8 constant rewardTokenDecimals = 18;

   
    TestERC20Token principalToken;
    uint8 constant principalTokenDecimals = 18;

    TestERC20Token collateralToken;
    uint8 constant collateralTokenDecimals = 6;

 

 

    constructor(  )
          MarketLiquidityRewards(
        address(0),
         address(0),
         address(0)
         ) {}

    function setUp() public {
        tellerV2Mock = new TellerV2Mock();
        mockMarketRegistry = new MarketRegistryMock(address(marketOwner));
        mockCollateralManager = new CollateralManagerMock();

        marketLiquidityRewards = new MarketLiquidityRewards(
            address(tellerV2Mock), 
            address(mockMarketRegistry),
            address(mockCollateralManager)
        );

        marketOwner = new MarketLiquidityUser(address(tellerV2Mock), (this));
        borrower = new MarketLiquidityUser(address(tellerV2Mock), (this));
        lender = new MarketLiquidityUser(address(tellerV2Mock), (this));
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

        rewardToken = new TestERC20Token(
            "Test Wrapped ETH",
            "TWETH",
            100000,
            rewardTokenDecimals
        );

        principalToken = new TestERC20Token(
            "Test Wrapped ETH",
            "TWETH",
            100000,
            principalTokenDecimals
        );

        collateralToken = new TestERC20Token(
            "Test USDC",
            "TUSDC",
            100000,
            collateralTokenDecimals
        );

        IERC20Upgradeable(address(rewardToken)).transfer(address(lender),10000);


        vm.warp(startTime+100);
        //delete allocationCount;
    }

    function _setAllocation(uint256 allocationId) internal {

        uint256 rewardTokenAmount = 0;

        RewardAllocation memory _allocation = IMarketLiquidityRewards.RewardAllocation({

            allocator: address(lender),
            marketId: marketId,
            rewardTokenAddress: address(rewardToken),
            rewardTokenAmount: rewardTokenAmount, 

            requiredPrincipalTokenAddress: address(principalToken),
            requiredCollateralTokenAddress: address(collateralToken),

            minimumCollateralPerPrincipalAmount: 0,
            rewardPerLoanPrincipalAmount: 0,

            
            bidStartTimeMin: uint32(startTime),
            bidStartTimeMax: uint32(startTime + 10000),

            allocationStrategy: AllocationStrategy.BORROWER 
        }); 

        allocatedRewards[allocationId] = _allocation;

    }


    function test_allocateRewards() public {

        uint256 rewardTokenAmount = 500;
        
        RewardAllocation memory _allocation = IMarketLiquidityRewards.RewardAllocation({

            allocator: address(lender),
            marketId: marketId,
            rewardTokenAddress: address(rewardToken),
            rewardTokenAmount: rewardTokenAmount, 

            requiredPrincipalTokenAddress: address(principalToken),
            requiredCollateralTokenAddress: address(collateralToken),

            minimumCollateralPerPrincipalAmount: 0,
            rewardPerLoanPrincipalAmount: 0,

            bidStartTimeMin: uint32(startTime),
            bidStartTimeMax: uint32(startTime + 10000),

            allocationStrategy: AllocationStrategy.BORROWER 
        }); 
 

        lender._approveERC20Token(
            address(rewardToken),
            address(this),
            rewardTokenAmount
        );

        uint256 allocationId = lender._allocateRewards(
            _allocation
        );

         /*  assertEq(
            allocationId,
            address(lender),
            "Allocate r"
        );*/

    }

      function test_increaseAllocationAmount() public {

        uint256 allocationId = 0;
        uint256 amountToIncrease = 100;
        

        _setAllocation(allocationId);

        uint256 amountBefore = allocatedRewards[allocationId].rewardTokenAmount;

        lender._approveERC20Token(
            address(rewardToken),
            address(this),
            amountToIncrease
        );

        lender._increaseAllocationAmount(
            allocationId,
            amountToIncrease
        );

        uint256 amountAfter = allocatedRewards[allocationId].rewardTokenAmount;


        assertEq(
            amountAfter,
            amountBefore + amountToIncrease,
            "Allocation did not increase"
        );

      }

/*

    deallocate

*/

/*

    claim rewards 

*/

 function test_calculateRewardAmount_weth_principal() public {

    uint256 loanPrincipal = 1e8;
    uint256 principalTokenDecimals = 18;

    uint256 rewardPerLoanPrincipalAmount = 1e16; // expanded by token decimals so really 0.01


    uint256 rewardAmount = super._calculateRewardAmount(
        loanPrincipal,
        principalTokenDecimals,
        rewardPerLoanPrincipalAmount
    );

     assertEq(
            rewardAmount,
            1e6,
            "Invalid reward amount"
        );



 }

  function test_calculateRewardAmount_usdc_principal() public {

    uint256 loanPrincipal = 1e8;
    uint256 principalTokenDecimals = 6;

    uint256 rewardPerLoanPrincipalAmount = 1e4; // expanded by token decimals so really 0.01


    uint256 rewardAmount = super._calculateRewardAmount(
        loanPrincipal,
        principalTokenDecimals,
        rewardPerLoanPrincipalAmount
    );

     assertEq(
            rewardAmount,
            1e6,
            "Invalid reward amount"
        );



 }

  function test_requiredCollateralAmount() public {

   
    uint256 collateralTokenDecimals = 6;

    uint256 loanPrincipal = 1e8;
    uint256 principalTokenDecimals = 6;

    uint256 minimumCollateralPerPrincipal = 1e4  * 1e6 ; // expanded by token decimals so really 0.01

    uint256 minCollateral = _requiredCollateralAmount(
        loanPrincipal,
        principalTokenDecimals,
        collateralTokenDecimals,
        minimumCollateralPerPrincipal
    );


     assertEq(
            minCollateral,
            1e6,
            "Invalid min collateral calculation"
        );

    
     
    
  }

/*
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

    function test_acceptCommitmentWithBorrowersArray_valid() public {
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
    }

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

   */
 
 function allocateRewards(
        MarketLiquidityRewards.RewardAllocation calldata _allocation        
    ) public override returns (uint256 allocationId_ ) {
         super.allocateRewards(_allocation);
    }

    function increaseAllocationAmount(
        uint256 _allocationId,
        uint256 _tokenAmount 
    ) public override {
        super.increaseAllocationAmount(_allocationId,_tokenAmount);
    }

    function deallocateRewards(
        uint256 _allocationId,
        uint256 _tokenAmount
    ) public override {
           super.deallocateRewards(_allocationId,_tokenAmount);
    }



 
}

contract MarketLiquidityUser is User {
    MarketLiquidityRewards public immutable liquidityRewards;

    constructor(
        address _tellerV2,
        MarketLiquidityRewards _liquidityRewards
    ) User(_tellerV2) {
        liquidityRewards = _liquidityRewards;
    }

    function _allocateRewards(
       MarketLiquidityRewards.RewardAllocation calldata _allocation  
    ) public returns (uint256) {
        return
            liquidityRewards.allocateRewards(
               _allocation
            );
    }

    function _increaseAllocationAmount(
        uint256 _allocationId,
        uint256 _allocationAmount
    ) public {
        liquidityRewards.increaseAllocationAmount(
            _allocationId, _allocationAmount);
    }
 

    function _claimRewards(
        uint256 _allocationId,
        uint256 _bidId 
    ) public  {
        return
            liquidityRewards.claimRewards(
                _allocationId,
                _bidId
            );
    }

    function _approveERC20Token(
        address tokenAddress,
        address guy,
        uint256 wad
    ) public  {
        IERC20Upgradeable(tokenAddress).approve(guy,wad);
    }

  
}
 
contract TellerV2Mock is TellerV2Context {
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
