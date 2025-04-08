pragma solidity ^0.8.0;

import { Testable } from "../../../Testable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { BorrowSwap_G2 } from "../../../../contracts/LenderCommitmentForwarder/extensions/rollover/BorrowSwap_G2.sol";

import "../../../../contracts/interfaces/ILenderCommitmentForwarder.sol";
import "../../../../contracts/interfaces/IFlashRolloverLoan.sol";

import "../../../integration/IntegrationTestHelpers.sol";

import { WethMock } from "../../../../contracts/mock/WethMock.sol";

import { TellerV2SolMock } from "../../../../contracts/mock/TellerV2SolMock.sol";
import { LenderCommitmentForwarderMock } from "../../../../contracts/mock/LenderCommitmentForwarderMock.sol";
import { MarketRegistryMock } from "../../../../contracts/mock/MarketRegistryMock.sol";

import { UniswapV3RouterMock } from "../../../../contracts/mock/uniswap/UniswapV3RouterMock.sol";
 
import {PoolAddress} from '../../../../contracts/libraries/uniswap/periphery/libraries/PoolAddress.sol';



contract BorrowSwapG2Override is BorrowSwap_G2 {

    address uniswapPoolMockAddress; 

    constructor(
        address _tellerV2,
        address _swapRouter 
        
    )
        BorrowSwap_G2(
            _tellerV2,
            _swapRouter 
        )
    {} 




   
 
}

contract BorrowSwap_G2_Unit_Test is Testable {
    constructor() {}

    User private borrower;
    User private lender;

    UniswapV3RouterMock uniswapRouterMock; 

    BorrowSwapG2Override borrowSwap;

    TellerV2SolMock tellerV2;
    WethMock wethMock;
     WethMock collateralToken;

    LenderCommitmentForwarderMock lenderCommitmentForwarder;
    MarketRegistryMock marketRegistryMock;

    function setUp() public {
        borrower = new User();
        lender = new User();

        tellerV2 = new TellerV2SolMock();
        wethMock = new WethMock();

        collateralToken = new WethMock();

        marketRegistryMock = new MarketRegistryMock();

        tellerV2.setMarketRegistry(address(marketRegistryMock));

        lenderCommitmentForwarder = new LenderCommitmentForwarderMock();


        wethMock.deposit{ value: 100e18 }();
        wethMock.transfer(address(lender), 5e18);
        wethMock.transfer(address(borrower), 5e18);
        wethMock.transfer(address(lenderCommitmentForwarder), 5e18);

            
       
        uniswapRouterMock = new UniswapV3RouterMock(); 
        wethMock.transfer(address(uniswapRouterMock), 5e18);

        borrowSwap = new BorrowSwapG2Override(
            address(tellerV2),
            address(uniswapRouterMock) 
        );

       // swapRolloverLoan.set_uniswapPoolMockAddress( address(uniswapPoolMock) );

        IntegrationTestHelpers.deployIntegrationSuite();
    }

    function test_borrowSwap() public {
        address lendingToken = address(wethMock);
     
        uint256 principalAmount = 5000;
        uint256 flashAmount = 5000; 
        uint32 duration = 10 days;
        uint16 interestRate = 100;

        bytes32[] memory merkleProof; 

        address rewardRecipient = address(0);
        uint256 rewardAmount = 0; 


{
        uint256 loanId = tellerV2.submitBid(
            lendingToken,
            0, //marketId,
            principalAmount,
            duration,
            interestRate,
            "",
            address(borrower)
        );
}
     


        ILenderCommitmentForwarder.Commitment
            memory commitment = ILenderCommitmentForwarder.Commitment({
                maxPrincipal: principalAmount,
                expiration: uint32(block.timestamp + 1 days),
                maxDuration: duration,
                minInterestRate: interestRate,
                collateralTokenAddress: address(0),
                collateralTokenId: 0,
                maxPrincipalPerCollateralAmount: 0,
                collateralTokenType: ILenderCommitmentForwarder
                    .CommitmentCollateralType
                    .NONE,
                lender: address(lender),
                marketId: 0,
                principalTokenAddress: lendingToken
            });

        lenderCommitmentForwarder.setCommitment(0, commitment);

        BorrowSwap_G2.AcceptCommitmentArgs
            memory commitmentArgs = BorrowSwap_G2.AcceptCommitmentArgs({
                commitmentId: 0,
                smartCommitmentAddress: address(0),
                principalAmount: principalAmount,
                collateralAmount: 100,
                collateralTokenId: 0,
                collateralTokenAddress: address(0),
                interestRate: interestRate,
                loanDuration: duration,
                merkleProof: merkleProof
            });


      
        BorrowSwap_G2.TokenSwapPath[] memory swapPaths = new BorrowSwap_G2.TokenSwapPath[](1);

 
        swapPaths[0] = BorrowSwap_G2.TokenSwapPath({
            poolFee: 3000,
            tokenOut: address(collateralToken) 
        });


        bytes memory path = abi.encodePacked( address(wethMock), uint24(3000), address(collateralToken))  ;

            BorrowSwap_G2.SwapArgs
            memory swapArgs = BorrowSwap_G2.SwapArgs({

                swapPaths: swapPaths,
                amountOutMinimum: 0,
                deadline: uint160( block.timestamp ) + uint160 (1e8 )  
 
           
            });

       
     
        
        vm.prank(address(borrower));
        IERC20(lendingToken).approve(address(borrowSwap), 1e18);

        vm.prank(address(borrower));
        borrowSwap.borrowSwap( 
            address(lenderCommitmentForwarder),
           
            address( lendingToken ),

            50, // borrowerAmount,
           
            swapArgs,
            commitmentArgs
        );

     
    }


       
 
}

contract User {}
