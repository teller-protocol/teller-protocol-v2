// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "./Testable.sol";

import { CollateralEscrowV1 } from "../contracts/escrow/CollateralEscrowV1.sol";
import "../contracts/mock/WethMock.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./tokens/TestERC20Token.sol";
import "./tokens/TestERC721Token.sol";
import "./tokens/TestERC1155Token.sol";

import "../contracts/mock/TellerV2SolMock.sol";
import "../contracts/CollateralManager.sol";

import "./CollateralManager_Override.sol";
 
contract CollateralManager_Test is Testable {
    CollateralManager_Override collateralManager;
    User private borrower;
    User private lender;
    User private liquidator;
   

    TestERC20Token wethMock;
    TestERC721Token erc721Mock;
    TestERC1155Token erc1155Mock;

    TellerV2_Mock tellerV2Mock;


    
     CollateralEscrowV1_Mock escrowImplementation = new CollateralEscrowV1_Mock();    
    /*

 
    FNDA:0,CollateralManager.onERC1155BatchReceived


    */

    function setUp() public {
        // Deploy implementation
         // Deploy implementation
       
        // Deploy beacon contract with implementation
        UpgradeableBeacon escrowBeacon = new UpgradeableBeacon(
            address(escrowImplementation)
        );

        
        wethMock = new TestERC20Token("wrappedETH", "WETH", 1e24, 18);
        erc721Mock = new TestERC721Token("ERC721", "ERC721");
        erc1155Mock = new TestERC1155Token("ERC1155");

        tellerV2Mock = new TellerV2_Mock();
        borrower = new User();
        lender = new User();
        liquidator = new User();


        // Deploy escrow
      /*  BeaconProxy proxy_ = new BeaconProxy(
            address(escrowBeacon),
            abi.encodeWithSelector(CollateralEscrowV1.initialize.selector, 0)
        );
        escrow = CollateralEscrowV1Mock(address(proxy_));
    */

      //  uint256 borrowerBalance = 50000;
     //   payable(address(borrower)).transfer(borrowerBalance);

        collateralManager = new CollateralManager_Override();


        collateralManager.initialize(address(escrowBeacon), address(tellerV2Mock) );
    } 


    function test_setCollateralEscrowBeacon(  ) public {
        // Deploy implementation
        CollateralEscrowV1 escrowImplementation = new CollateralEscrowV1_Mock();
        // Deploy beacon contract with implementation
        UpgradeableBeacon escrowBeacon = new UpgradeableBeacon(
            address(escrowImplementation)
        );

        

        collateralManager.setCollateralEscrowBeacon(address(escrowBeacon));
        
        //how to test ?
    }

    function test_setCollateralEscrowBeacon_invalid_twice() public {

        CollateralEscrowV1 escrowImplementation = new CollateralEscrowV1_Mock();
        // Deploy beacon contract with implementation
        UpgradeableBeacon escrowBeacon = new UpgradeableBeacon(
            address(escrowImplementation)
        );
        collateralManager.setCollateralEscrowBeacon(address(escrowBeacon));
        
        vm.expectRevert("Initializable: contract is already initialized");
        collateralManager.setCollateralEscrowBeacon(address(escrowBeacon));
        // 

    }


    
    function test_deposit() public  {
        uint256 bidId = 0 ;
        uint256 amount = 1000;
        wethMock.transfer(address(borrower), amount);

        borrower.approveERC20( address(wethMock), address(collateralManager), amount  );
    

        Collateral memory collateral = Collateral({
            _collateralType: CollateralType.ERC20,
            _amount: amount,
            _tokenId: 0, 
            _collateralAddress: address(wethMock)
        });

        tellerV2Mock.setBorrower(address(borrower));

        collateralManager._depositSuper(bidId, collateral);

         
    }

    function test_deposit_erc20() public  {
        uint256 bidId = 0 ;
        uint256 amount = 1000;
        wethMock.transfer(address(borrower), amount);

        borrower.approveERC20( address(wethMock), address(collateralManager), amount  );
    

        Collateral memory collateral = Collateral({
            _collateralType: CollateralType.ERC20,
            _amount: amount,
            _tokenId: 0, 
            _collateralAddress: address(wethMock)
        });

        tellerV2Mock.setBorrower(address(borrower));

        collateralManager._depositSuper(bidId, collateral);


        assertEq(escrowImplementation.depositAssetWasCalled(), true, "deposit token was not called");
         
    }

        function test_deposit_erc721() public  {
        uint256 bidId = 0 ;
        uint256 amount = 1000;
        wethMock.transfer(address(borrower), amount);

        borrower.approveERC20( address(wethMock), address(collateralManager), amount  );
    

        Collateral memory collateral = Collateral({
            _collateralType: CollateralType.ERC721,
            _amount: amount,
            _tokenId: 0, 
            _collateralAddress: address(wethMock)
        });

        tellerV2Mock.setBorrower(address(borrower));

        collateralManager._depositSuper(bidId, collateral);


        assertEq(escrowImplementation.depositAssetWasCalled(), true, "deposit asset was not called");
         
    }


    function test_deposit_erc1155() public  {
        uint256 bidId = 0 ;
        uint256 amount = 1000;
        wethMock.transfer(address(borrower), amount);

        borrower.approveERC20( address(wethMock), address(collateralManager), amount  );
    

        Collateral memory collateral = Collateral({
            _collateralType: CollateralType.ERC1155,
            _amount: amount,
            _tokenId: 0, 
            _collateralAddress: address(wethMock)
        });

        tellerV2Mock.setBorrower(address(borrower));

        collateralManager._depositSuper(bidId, collateral);


        assertEq(escrowImplementation.depositAssetWasCalled(), true, "deposit asset was not called");
         
    }

 

    function test_deposit_invalid_bid() public  {
        uint256 bidId = 0 ;
        uint256 amount = 1000;
        wethMock.transfer(address(borrower), amount);
        wethMock.approve(address(collateralManager), amount);

        Collateral memory collateral = Collateral({
            _collateralType: CollateralType.ERC20,
            _amount: amount,
            _tokenId: 0, 
            _collateralAddress: address(wethMock)
        });


        tellerV2Mock.setBorrower(address(0));

        vm.expectRevert("Bid does not exist");
        collateralManager._depositSuper(bidId, collateral);

       
         
    }


    function test_deployAndDeposit_invalid_sender() public {


        vm.prank(address(lender)); 
        vm.expectRevert("Sender not authorized");

        collateralManager.deployAndDeposit(0);

    } 

    function test_deployAndDeposit() public {

        uint256 bidId = 0 ;
        uint256 amount = 1000;
        wethMock.transfer(address(borrower), amount);
        wethMock.approve(address(collateralManager), amount);

        Collateral memory collateral = Collateral({
            _collateralType: CollateralType.ERC20,
            _amount: amount,
            _tokenId: 0, 
            _collateralAddress: address(wethMock)
        });

        tellerV2Mock.setBorrower(address(borrower));
 
        vm.prank(address(tellerV2Mock));
        collateralManager.deployAndDeposit(bidId);

       // assertEq(escrowImplementation.depositTokenWasCalled(), true, "deposit token was not called");
         
    }



    function test_deployAndDeposit_not_collateral_backed() public {}

 

    function test_initialize_again() public {

        vm.expectRevert("Initializable: contract is already initialized");
        collateralManager.initialize(address(0), address(0) );

    }
 

    function test_withdraw_external_invalid_bid_state() public {

        uint256 bidId = 0;

        vm.expectRevert("collateral cannot be withdrawn");

        collateralManager.withdraw(bidId); 
        
    }

    function test_withdraw_external_state_paid() public {
        
        uint256 bidId = 0;

        tellerV2Mock.setBorrower(address(borrower));
        tellerV2Mock.setGlobalBidState(BidState.PAID);

        collateralManager.withdraw(bidId);

        assertTrue(collateralManager.withdrawInternalWasCalledToRecipient()==address(borrower),"withdraw internal was not called with correct recipient");


    }

    function test_withdraw_external_state_defaulted() public {
            
        uint256 bidId = 0;

        tellerV2Mock.setLender(address(lender));
        tellerV2Mock.setBidsDefaultedGlobally(true);

        collateralManager.withdraw(bidId);

        assertTrue(collateralManager.withdrawInternalWasCalledToRecipient()==address(lender),"withdraw internal was not called with correct recipient");


    }


  function test_liquidateCollateral_invalid_sender() public {

        uint256 bidId = 0;

       
        tellerV2Mock.setGlobalBidState(BidState.LIQUIDATED);
    
        vm.expectRevert("Sender not authorized");
        collateralManager.liquidateCollateral(bidId, address(liquidator));

      
    }

    function test_liquidateCollateral_invalid_state() public {

        uint256 bidId = 0;

        collateralManager.setBidsCollateralBackedGlobally(true);

        vm.prank(address(tellerV2Mock));
        //tellerV2Mock.setGlobalBidState(BidState.LIQUIDATED);
    
        vm.expectRevert("Loan has not been liquidated");
        collateralManager.liquidateCollateral(bidId, address(liquidator));

      
    }

    function test_liquidateCollateral_not_backed() public {

        uint256 bidId = 0;

      
        collateralManager.setBidsCollateralBackedGlobally(false);

        tellerV2Mock.setGlobalBidState(BidState.PENDING);

        vm.prank(address(tellerV2Mock));
        collateralManager.liquidateCollateral(bidId, address(liquidator));

        assertTrue(collateralManager.withdrawInternalWasCalledToRecipient()==address(0),"withdraw internal should not have been called");

    }
   
   
    function test_liquidateCollateral() public {

        uint256 bidId = 0;

      
        collateralManager.setBidsCollateralBackedGlobally(true);

        tellerV2Mock.setGlobalBidState(BidState.LIQUIDATED);

        vm.prank(address(tellerV2Mock));
        collateralManager.liquidateCollateral(bidId, address(liquidator));

        assertTrue(collateralManager.withdrawInternalWasCalledToRecipient()==address(liquidator),"withdraw internal was not called with correct recipient");

    }
   
    function test_withdraw_internal() public {


        uint256 bidId = 0;
        address recipient = address(borrower);


        // the escrows should be mocked.. so escrow .withdraw is just mocked 


        collateralManager.withdraw_internal(bidId,recipient);

    }
/*
    function test_withdraw_internal_invalid_bid() public {

        uint256 bidId = 0;
        address recipient = address(borrower);

        vm.expectRevert("Bid does not exist");
        collateralManager.withdraw_internal(bidId,recipient);

    }
*/

    function test_getCollateralInfo() public {

        uint256 bidId = 0;

        Collateral memory collateral = Collateral({
            _collateralType: CollateralType.ERC20,
            _amount: 1000,
            _tokenId: 0, 
            _collateralAddress: address(wethMock)
        });

        collateralManager.commitCollateralSuper(bidId, collateral);

        Collateral[] memory collateralInfo = collateralManager.getCollateralInfo(bidId);

        assertTrue(collateralInfo[0]._collateralType == CollateralType.ERC20, "collateral type is not correct");
        assertTrue(collateralInfo[0]._amount == 1000, "collateral amount is not correct");
        assertTrue(collateralInfo[0]._tokenId == 0, "collateral tokenId is not correct");
        assertTrue(collateralInfo[0]._collateralAddress == address(wethMock), "collateral address is not correct");

    }

    function test_getCollateralAmount() public {

        uint256 bidId = 0;

        Collateral memory collateral = Collateral({
            _collateralType: CollateralType.ERC20,
            _amount: 1000,
            _tokenId: 0, 
            _collateralAddress: address(wethMock)
        });

        collateralManager.commitCollateralSuper(bidId, collateral);

        uint256 collateralAmount = collateralManager.getCollateralAmount(bidId,address(wethMock));

        assertTrue(collateralAmount == 1000, "collateral amount is not correct");

    }

    function test_getEscrow() public {

        uint256 bidId = 0;

        address escrow = collateralManager.getEscrow(bidId);

        assertTrue(escrow == address(0), "escrow is not correct");

    }

    function test_deployEscrow_internal() public {

        uint256 bidId = 0;

        tellerV2Mock.setBorrower(address(borrower));

        //use the mock escrow imp
        collateralManager.setGlobalEscrowProxyAddress(  address(escrowImplementation) );

        (address proxy, address borrower) = collateralManager._deployEscrowSuper(bidId);
 
    }

      function test_deployEscrow_internal_nonexisting_bid() public {

        uint256 bidId = 0;

        vm.expectRevert("Bid does not exist");
        (address proxy, address borrower) = collateralManager._deployEscrowSuper(bidId);
 
    }


    function test_isBidCollateralBacked_empty() public {

        uint256 bidId = 0;

        bool collateralBacked = collateralManager.isBidCollateralBackedSuper(bidId);

        assertTrue(collateralBacked == false, "collateral backed is not correct");

    }

     function test_isBidCollateralBacked_populated() public {

        uint256 bidId = 0;

        Collateral memory collateral = Collateral({
            _collateralType: CollateralType.ERC20,
            _amount: 1000,
            _tokenId: 0, 
            _collateralAddress: address(wethMock)
        });

        collateralManager.commitCollateralSuper(bidId, collateral);


        bool collateralBacked = collateralManager.isBidCollateralBackedSuper(bidId);

        assertTrue(collateralBacked, "collateral backed is not correct");

    }



    function test_onERC721Received() public {

       bytes4 response = collateralManager.onERC721Received(address(this), address(borrower), 0, "");

       assertEq(response, bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")),"response is not correct");

    }

    function test_onERC1155Received() public {

       bytes4 response = collateralManager.onERC1155Received(address(this), address(borrower), 0, 0, "");

       assertEq(response, bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)")),"response is not correct");

    } 
    


    function test_checkBalances_empty() public {

        Collateral[] memory collateralArray; 

        (bool valid, bool[] memory checks) = collateralManager.checkBalances(
            address(borrower),
            collateralArray
        );

        assertTrue(valid);
    }

    function test_checkBalances_public() public {

        Collateral[] memory collateralArray = new Collateral[](1); 

        collateralArray[0] = Collateral({
            _collateralType: CollateralType.ERC20,
            _amount: 1000,
            _tokenId: 0, 
            _collateralAddress: address(wethMock)
        });
 
 
        (bool valid, bool[] memory checks) = collateralManager.checkBalances(
            address(borrower),
            collateralArray
        );
 

        assertTrue(collateralManager.checkBalancesWasCalled(), "Check balances was not called");
    }

     function test_checkBalances_internal() public {
    
        
        Collateral[] memory collateralArray = new Collateral[](1); 

        collateralArray[0] = Collateral({
            _collateralType: CollateralType.ERC20,
            _amount: 1000,
            _tokenId: 0, 
            _collateralAddress: address(wethMock)
        });
 
 
        (bool valid, bool[] memory checks) = collateralManager._checkBalancesSuper(
            address(borrower),
            collateralArray,
            true 
        );
 
        assertTrue(collateralManager.checkBalanceWasCalled(), "Check balance was not called");
     }



     function test_checkBalance_internal_insufficient_assets() public {

          Collateral memory collateral =  Collateral({
            _collateralType: CollateralType.ERC20,
            _amount: 1000,
            _tokenId: 0, 
            _collateralAddress: address(wethMock)
        });


        bool valid = collateralManager._checkBalanceSuper(
            address(borrower),
            collateral
        );
 

        //need to inject state 

        assertFalse(valid, "check balance super should be invalid");
     }


     function test_checkBalance_internal_sufficient_assets() public {

          Collateral memory collateral =  Collateral({
            _collateralType: CollateralType.ERC20,
            _amount: 1000,
            _tokenId: 0, 
            _collateralAddress: address(wethMock)
        });


        wethMock.transfer(address(borrower),1000);


        bool valid = collateralManager._checkBalanceSuper(
            address(borrower),
            collateral
        );
 

        //need to inject state 

        assertTrue(valid, "check balance super not valid");
     }


    function test_revalidateCollateral() public {

        Collateral[] memory collateralArray; 

        uint256 bidId = 0;

        bool valid =  collateralManager.revalidateCollateral(
            bidId
        );

        assertTrue(valid);
    }

    function test_commit_collateral_single() public {
        uint256 bidId = 0;

        Collateral memory collateral = Collateral({
            _collateralType: CollateralType.ERC20,
            _amount: 1000,
            _tokenId: 0, 
            _collateralAddress: address(wethMock)
        });

        
        collateralManager.commitCollateral(bidId,collateral);


        assertTrue(collateralManager.commitCollateralInternalWasCalled(),"commit collateral was not called");

    }

    function test_commit_collateral_array() public {
        uint256 bidId = 0;

        Collateral[] memory collateralArray = new Collateral[](1); 

        collateralArray[0] = Collateral({
            _collateralType: CollateralType.ERC20,
            _amount: 1000,
            _tokenId: 0, 
            _collateralAddress: address(wethMock)
        });

       
        collateralManager.commitCollateral(bidId, collateralArray);

        assertTrue(collateralManager.commitCollateralInternalWasCalled(),"commit collateral was not called");

    }
  
}

contract User {
   

    constructor( ) {
    
       
    }



    function approveERC20(address tokenAddress, address to, uint256 amount) public {
        ERC20(tokenAddress).approve(address(to), amount);
    }


 
    receive() external payable {}

    //receive 721
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        return this.onERC721Received.selector;
    }

    //receive 1155
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        return this.onERC1155Received.selector;
    }



}


contract CollateralEscrowV1_Mock is CollateralEscrowV1 {
    
    bool public depositAssetWasCalled;

    constructor() CollateralEscrowV1() {}


    function depositAsset(
          CollateralType _collateralType,
        address _collateralAddress,
        uint256 _amount,
        uint256 _tokenId
    ) external payable override {
        depositAssetWasCalled = true;
    }


    
}

contract TellerV2_Mock is TellerV2SolMock {

    address public globalBorrower;
    address public globalLender;
    bool public bidsDefaultedGlobally;
    BidState public globalBidState;

    constructor() TellerV2SolMock() {}

    function setBorrower(address borrower) public {
        globalBorrower = borrower;
    }

     function setLender(address lender) public {
        globalLender = lender;
    }

    
    function getLoanBorrower(uint256 bidId) public view override returns (address) {
        return address(globalBorrower);
    }
     function getLoanLender(uint256 bidId) public view override returns (address) {
        return address(globalLender);
    }

    function isLoanDefaulted(uint256 _bidId) public view override returns (bool) {
        return bidsDefaultedGlobally;
    }

    function getBidState(uint256 _bidId) public view override returns (BidState) {
        return globalBidState;
    }

    function setGlobalBidState(BidState _state) public {
        globalBidState = _state;
    }

    function setBidsDefaultedGlobally(bool _defaulted) public {
        bidsDefaultedGlobally = _defaulted;
    }


        

    
}