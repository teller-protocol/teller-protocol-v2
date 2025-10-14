pragma solidity ^0.8.0;

import { Testable } from "../../../Testable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { SwapRolloverLoan_G2 } from "../../../../contracts/LenderCommitmentForwarder/extensions/rollover/SwapRolloverLoan_G2.sol";

import "../../../../contracts/interfaces/ILenderCommitmentForwarder.sol";
import "../../../../contracts/interfaces/IFlashRolloverLoan.sol";

import "../../../integration/IntegrationTestHelpers.sol";

import { WethMock } from "../../../../contracts/mock/WethMock.sol";

import { TellerV2SolMock } from "../../../../contracts/mock/TellerV2SolMock.sol";
import { LenderCommitmentForwarderMock } from "../../../../contracts/mock/LenderCommitmentForwarderMock.sol";
import { MarketRegistryMock } from "../../../../contracts/mock/MarketRegistryMock.sol";

import { LenderCommitmentGroup_Pool_V2 } from "../../../../contracts/LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Pool_V2.sol";

import { ILenderCommitmentGroup_V2 } from "../../../../contracts/interfaces/ILenderCommitmentGroup_V2.sol";
import { IUniswapPricingLibrary } from "../../../../contracts/interfaces/IUniswapPricingLibrary.sol";




import { UniswapV3FactoryMock } from "../../../../contracts/mock/uniswap/UniswapV3FactoryMock.sol";
import { UniswapV3PoolMock } from "../../../../contracts/mock/uniswap/UniswapV3PoolMock.sol";

import {PoolAddress} from '../../../../contracts/libraries/uniswap/periphery/libraries/PoolAddress.sol';

import { UniswapPricingHelper } from "../../../../contracts/price_oracles/UniswapPricingHelper.sol";
import { SmartCommitmentForwarder } from "../../../../contracts/LenderCommitmentForwarder/SmartCommitmentForwarder.sol";


contract SwapRolloverLoanOverride is SwapRolloverLoan_G2 {

    address uniswapPoolMockAddress; 

    constructor(
        address _tellerV2,
        address _factory,
        address _WETH9
        
    )
        SwapRolloverLoan_G2(
            _tellerV2,
            _factory,
            _WETH9
        )
    {} 




    function _verifyFlashCallback( 
         
        address token0,
        address token1,
        uint24 fee,
        address _msgSender 


     ) internal  override {
        
        //  we have to stub away this check in testing 

    }


    function set_uniswapPoolMockAddress(address _pool) public {
        uniswapPoolMockAddress = _pool; 
    }
   
      function getUniswapPoolAddress(  
        address token0,
        address token1,
        uint24 fee
     ) public view override returns (address) {

        return  uniswapPoolMockAddress ;

    }

 
}

contract SwapRolloverLoan_Unit_Test is Testable {
    constructor() {}

    User private borrower;
    User private lender;

    UniswapV3PoolMock uniswapPoolMock;
    UniswapV3FactoryMock uniswapFactoryMock;

    SwapRolloverLoanOverride swapRolloverLoan;
    TellerV2SolMock tellerV2;
    WethMock wethMock;
     WethMock collateralToken;
    LenderCommitmentForwarderMock lenderCommitmentForwarder;
    MarketRegistryMock marketRegistryMock;


    SmartCommitmentForwarder smartCommitmentForwarder;

    UniswapPricingHelper uniswapPricingHelper; 


    LenderCommitmentGroup_Pool_V2 tellerPool; 

    function setUp() public {
        borrower = new User();
        lender = new User();

        tellerV2 = new TellerV2SolMock();
        wethMock = new WethMock();

         collateralToken = new WethMock();

        marketRegistryMock = new MarketRegistryMock();

        tellerV2.setMarketRegistry(address(marketRegistryMock));


        lenderCommitmentForwarder = new LenderCommitmentForwarderMock();

       
        uniswapPoolMock = new UniswapV3PoolMock(); 
        uniswapPoolMock.set_mockToken0(address(wethMock));
        uniswapPoolMock.set_mockToken1(address(collateralToken));
        uniswapPoolMock.set_mockFee(100);

         
        uniswapFactoryMock = new UniswapV3FactoryMock();

        uniswapPricingHelper = new UniswapPricingHelper();

        smartCommitmentForwarder = new SmartCommitmentForwarder( 
             address(tellerV2),
             address(marketRegistryMock) 
            ); 

       //  tellerV2.setTrustedMarketForwarder(  1,  address(smartCommitmentForwarder) );


        wethMock.deposit{ value: 100e18 }();
        wethMock.transfer(address(lender), 5e18);
        wethMock.transfer(address(borrower), 5e18);
        wethMock.transfer(address(lenderCommitmentForwarder), 5e18);

        wethMock.transfer(address(uniswapPoolMock), 5e18);

 
        tellerPool = new LenderCommitmentGroup_Pool_V2(
            address(tellerV2),
            address(smartCommitmentForwarder),
            address(uniswapFactoryMock),
            address(uniswapPricingHelper)
        );



        ILenderCommitmentGroup_V2.CommitmentGroupConfig memory commitmentGroupConfig = ILenderCommitmentGroup_V2.CommitmentGroupConfig({
            principalTokenAddress: address(wethMock) ,
            collateralTokenAddress: address(collateralToken),
            marketId: 1,
            maxLoanDuration: 604800,
            interestRateLowerBound: 100,
            interestRateUpperBound: 1000,
            liquidityThresholdPercent: 8000,
            collateralRatio: 40000
        });

         IUniswapPricingLibrary.PoolRouteConfig[] memory routes = new IUniswapPricingLibrary.PoolRouteConfig[](1);

         routes[0] = IUniswapPricingLibrary.PoolRouteConfig({
            pool: 0xbe352daF66af94ccF2012a154a67DAEF95FAcB91,
            zeroForOne: true,
            twapInterval: 5,
            token0Decimals: 18,
            token1Decimals: 18
        });


           vm.prank( address(lender) );
        tellerPool.initialize(
            commitmentGroupConfig,
            routes
        ); 

      

        swapRolloverLoan = new SwapRolloverLoanOverride(
            address(tellerV2),
            address(uniswapFactoryMock),
            address(wethMock)
        );

        swapRolloverLoan.set_uniswapPoolMockAddress( address(uniswapPoolMock) );

        IntegrationTestHelpers.deployIntegrationSuite();
    }

    function test_rolloverLoanWithFlashSwap() public {
        address lendingToken = address(wethMock);
        uint256 marketId = 0;
        uint256 principalAmount = 5000;
        uint256 flashAmount = 5000; 
        uint32 duration = 10 days;
        uint16 interestRate = 100;

        bytes32[] memory merkleProof; 

        address rewardRecipient = address(0);
        uint256 rewardAmount = 0; 



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
                marketId: marketId,
                principalTokenAddress: lendingToken
            });

        lenderCommitmentForwarder.setCommitment(0, commitment);

        SwapRolloverLoan_G2.AcceptCommitmentArgs
            memory commitmentArgs = SwapRolloverLoan_G2.AcceptCommitmentArgs({
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


            SwapRolloverLoan_G2.FlashSwapArgs
            memory flashSwapArgs = SwapRolloverLoan_G2.FlashSwapArgs({
                token0: address(lendingToken),
                token1: address(collateralToken),
                fee: 100,
                flashAmount: flashAmount,
                borrowToken1: false 
             //   poolAddress: address( uniswapPoolMock )
            });

        vm.prank(address(borrower));
        uint256 loanId = tellerV2.submitBid(
            lendingToken,
            marketId,
            principalAmount,
            duration,
            interestRate,
            "",
            address(borrower)
        );

     
        uint256 borrowerAmount = 50; //have to pay the   fee..

        vm.prank(address(borrower));
        IERC20(lendingToken).approve(address(swapRolloverLoan), 1e18);

        vm.prank(address(borrower));

        swapRolloverLoan.rolloverLoanWithFlashSwap( 
            address(lenderCommitmentForwarder),
            loanId, 
            borrowerAmount,
           // rewardAmount,
        //    rewardRecipient, 

            flashSwapArgs,
            commitmentArgs
        );

     
    }

    function test_rolloverLoanWithFlashSwap_alternate_collateral() public {
        address lendingToken = address(wethMock);

        WethMock otherCollateralToken = new WethMock(); 

        uint256 marketId = 0;
        uint256 principalAmount = 5000;
        uint256 flashAmount = 5000; 
        uint32 duration = 1 days;
        uint16 interestRate = 2000;

        bytes32[] memory merkleProof; 

        address rewardRecipient = address(0);
        uint256 rewardAmount = 0; 



        ILenderCommitmentForwarder.Commitment
            memory commitment = ILenderCommitmentForwarder.Commitment({
                maxPrincipal: principalAmount,
                expiration: uint32(block.timestamp + 1 days),
                maxDuration: duration,
                minInterestRate: interestRate,
                collateralTokenAddress: address( otherCollateralToken ),
                collateralTokenId: 0,
                maxPrincipalPerCollateralAmount: 0,
                collateralTokenType: ILenderCommitmentForwarder
                    .CommitmentCollateralType
                    .NONE,
                lender: address(lender),
                marketId: marketId,
                principalTokenAddress: lendingToken
            });

       //  lenderCommitmentForwarder.setCommitment(0, commitment);

        SwapRolloverLoan_G2.AcceptCommitmentArgs
            memory commitmentArgs = SwapRolloverLoan_G2.AcceptCommitmentArgs({
                commitmentId: 0,
                smartCommitmentAddress: address(  tellerPool   ),
                principalAmount: principalAmount,
                collateralAmount: 100,
                collateralTokenId: 0,
                collateralTokenAddress: address( collateralToken  ),
                interestRate: interestRate,
                loanDuration: duration,
                merkleProof: merkleProof
            });


            SwapRolloverLoan_G2.FlashSwapArgs
            memory flashSwapArgs = SwapRolloverLoan_G2.FlashSwapArgs({
                token0: address(lendingToken),
                token1: address(collateralToken),
                fee: 100,
                flashAmount: flashAmount,
                borrowToken1: false 
             //   poolAddress: address( uniswapPoolMock )
            });

        vm.prank(address(borrower));
        uint256 loanId = tellerV2.submitBid(
            lendingToken,
            marketId,
            principalAmount,
            duration,
            interestRate,
            "",
            address(borrower)
        );

     
        uint256 borrowerAmount = 50; //have to pay the   fee..

        vm.prank(address(borrower));
        IERC20(lendingToken).approve(address(swapRolloverLoan), 1e18);

        vm.prank(address(borrower));

        swapRolloverLoan.rolloverLoanWithFlashSwap( 
            address( smartCommitmentForwarder  ),
            loanId, 
            borrowerAmount,
           // rewardAmount,
        //    rewardRecipient, 

            flashSwapArgs,
            commitmentArgs
        );

     
    }




      function test_calculateRolloverAmount() public {
        address lendingToken = address(wethMock);
        // uint256 marketId = 0;
        uint256 principalAmount = 5000;
        uint256 flashAmount = 5000; 
       // uint32 duration = 10 days;
      //  uint16 interestRate = 100;

       
 
        

        vm.prank(address(borrower));
        uint256 loanId = tellerV2.submitBid(
            lendingToken,
            0,
            principalAmount,
            10 days,
            100,
            "",
            address(borrower)
        );  

        vm.prank(address(lender));
        IERC20(lendingToken).approve(address(tellerV2), 1e18);


        vm.prank(address(lender));
          tellerV2.lenderAcceptBid(0 );


 

     //   uint256 flashAmount = 500;
        uint256 borrowerAmount = 50; //have to pay the   fee..

        vm.prank(address(borrower));
        IERC20(lendingToken).approve(address(swapRolloverLoan), 1e18);

        vm.prank(address(borrower));


        uint16 marketFeePct = 0 ;

        uint16 protocolFeePct = 0;

        uint16 flashLoanFeePct = 3000;  // standard uniswap fee  


        uint256 timestamp = block.timestamp ; 


        (uint256 _flashAmount, int256 _borrowerAmount ) = swapRolloverLoan.calculateRolloverAmount( 
            marketFeePct,
            protocolFeePct,
            loanId,
            principalAmount, 

            0,
            flashLoanFeePct,
            timestamp 
       
        );

        assertEq( _flashAmount , 5000 );

        assertEq( _borrowerAmount , -15 );  //borrower needs to provide 50 


      
    }
 
}

contract User {}
