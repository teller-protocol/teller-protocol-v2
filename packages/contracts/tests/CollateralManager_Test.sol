// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "./Testable.sol";

import { CollateralEscrowV1 } from "../contracts/escrow/CollateralEscrowV1.sol";
import "../contracts/mock/WethMock.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/interfaces/IWETH.sol";

import "./tokens/TestERC20Token.sol";
import "./tokens/TestERC721Token.sol";
import "./tokens/TestERC1155Token.sol";

import "../contracts/mock/TellerV2SolMock.sol";
import "../contracts/CollateralManager.sol";
 
contract CollateralManager_Test is Testable {
    CollateralManager collateralManager;
    User private borrower;
   

    TestERC20Token wethMock;
    TestERC721Token erc721Mock;
    TestERC1155Token erc1155Mock;

    TellerV2SolMock tellerV2Mock;
   

    function setUp() public {
        // Deploy implementation
         // Deploy implementation
        CollateralEscrowV1 escrowImplementation = new CollateralEscrowV1_Mock();
        // Deploy beacon contract with implementation
        UpgradeableBeacon escrowBeacon = new UpgradeableBeacon(
            address(escrowImplementation)
        );

        
        wethMock = new TestERC20Token("wrappedETH", "WETH", 1e24, 18);
        erc721Mock = new TestERC721Token("ERC721", "ERC721");
        erc1155Mock = new TestERC1155Token("ERC1155");

        tellerV2Mock = new TellerV2SolMock();
       // borrower = new User(escrowBeacon, address(wethMock), address(erc721Mock), address(erc1155Mock));


        // Deploy escrow
      /*  BeaconProxy proxy_ = new BeaconProxy(
            address(escrowBeacon),
            abi.encodeWithSelector(CollateralEscrowV1.initialize.selector, 0)
        );
        escrow = CollateralEscrowV1Mock(address(proxy_));
    */

      //  uint256 borrowerBalance = 50000;
     //   payable(address(borrower)).transfer(borrowerBalance);

        collateralManager = new CollateralManager();


        collateralManager.initialize(address(escrowBeacon), address(tellerV2Mock) );
    } 

  
}

contract User {
   

    constructor( ) {
    
       
    }

  
/*
    function depositToken(
        
        address _collateralAddress,
        uint256 _amount
       
    ) public {
        escrow.depositToken(
         
            _collateralAddress,
            _amount
           
        );
    }

    function withdraw(
        address _collateralAddress,
        uint256 _amount,
        address _recipient
    ) public {
        escrow.withdraw(_collateralAddress, _amount, _recipient);
    }

    

    function approveERC20(address tokenAddress, uint256 amount) public {
        ERC20(tokenAddress).approve(address(escrow), amount);
    }

     function approveERC721(address tokenAddress,uint256 tokenId) public {
        ERC721(tokenAddress).approve(address(escrow), tokenId);
    }

     function approveERC1155(address tokenAddress) public {
        ERC1155(tokenAddress).setApprovalForAll(address(escrow), true);
    }

    function getBalance(address _collateralAddress)
        public
        returns (uint256 amount_)
    {
        (, amount_, , ) = escrow.collateralBalances(_collateralAddress);
    }
*/
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
    constructor() CollateralEscrowV1() {}

    
}