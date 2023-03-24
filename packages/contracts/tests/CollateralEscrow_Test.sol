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

import { CollateralType, CollateralEscrowV1 } from "../contracts/escrow/CollateralEscrowV1.sol";

import { CollateralEscrowV1_Override } from "./CollateralEscrow_Override.sol";

contract CollateralEscrow_Test is Testable {
    BeaconProxy private proxy_;
    User private borrower;
    //WethMock wethMock;

    TestERC20Token wethMock;
    TestERC721Token erc721Mock;
    TestERC1155Token erc1155Mock;
 
    



    uint256 amount = 1000;

    function setUp() public {
        // Deploy implementation
        CollateralEscrowV1 escrowImplementation = new CollateralEscrowV1_Override();
        // Deploy beacon contract with implementation
        UpgradeableBeacon escrowBeacon = new UpgradeableBeacon(
            address(escrowImplementation)
        );
        
        wethMock = new TestERC20Token("wrappedETH", "WETH", 1e24, 18);
        erc721Mock = new TestERC721Token("ERC721", "ERC721");
        erc1155Mock = new TestERC1155Token("ERC1155");

        borrower = new User(escrowBeacon, address(wethMock), address(erc721Mock), address(erc1155Mock));

      

        uint256 borrowerBalance = 50000;
        payable(address(borrower)).transfer(borrowerBalance);

       
    }

   /* function test_depositAsset() public {
        _depositAsset();
    }*/

    function test_withdrawAsset_ERC20() public {
         

        CollateralEscrowV1_Override escrow = CollateralEscrowV1_Override(address(borrower.getEscrow()));
 

        wethMock.transfer(address(escrow),amount);
        escrow.setStoredBalance(CollateralType.ERC20, address(wethMock), amount, 0, address(borrower) );

        

        borrower.withdraw(address(wethMock), amount, address(borrower));

        uint256 storedBalance = borrower.getBalance(address(wethMock));

        assertEq(storedBalance, 0, "Stored balance was not withdrawn");

        try borrower.withdraw(address(wethMock), amount, address(borrower)) {
            fail("No collateral balance for asset");
        } catch Error(string memory reason) {
            assertEq(
                reason,
                "No collateral balance for asset",
                "Should not be able to withdraw already withdrawn assets"
            );
        } catch {
            fail("Unknown error");
        }
    }

       function test_withdrawAsset_ERC721() public {
         

        CollateralEscrowV1_Override escrow = CollateralEscrowV1_Override(address(borrower.getEscrow()));
 

        uint256 tokenId = erc721Mock.mint(address(escrow));
        escrow.setStoredBalance(CollateralType.ERC721, address(erc721Mock), 1, tokenId, address(borrower) );

        
        borrower.withdraw(address(erc721Mock), 1, address(borrower));



        uint256 storedBalance = borrower.getBalance(address(erc721Mock));

        assertEq(storedBalance, 0, "Stored balance was not withdrawn");

        try borrower.withdraw(address(erc721Mock), 1, address(borrower)) {
            fail("No collateral balance for asset");
        } catch Error(string memory reason) {
            assertEq(
                reason,
                "No collateral balance for asset",
                "Should not be able to withdraw already withdrawn assets"
            );
        } catch {
            fail("Unknown error");
        }
    }

    function test_depositToken_ERC20() public {



        wethMock.transfer(address(borrower),1e18);

        borrower.approveERC20(address(wethMock), amount);

        borrower.depositToken(  address(wethMock), amount );

        uint256 storedBalance = borrower.getBalance(address(wethMock));

        assertEq(storedBalance, amount, "Escrow deposit unsuccessful");
    }

    function test_depositAsset_ERC20() public {


        wethMock.transfer(address(borrower),1e18);
        borrower.approveERC20(address(wethMock), amount);

        borrower.deposit(CollateralType.ERC20, address(wethMock), amount, 0);

        uint256 storedBalance = borrower.getBalance(address(wethMock));

        assertEq(storedBalance, amount, "Escrow deposit unsuccessful");
    }


    function test_depositAsset_ERC721() public {
        uint256 tokenId =  erc721Mock.mint(address(borrower));

        borrower.approveERC721(address(erc721Mock), tokenId);         

        borrower.deposit(CollateralType.ERC721, address(erc721Mock), 1, tokenId);

        uint256 storedBalance = borrower.getBalance(address(erc721Mock));

        assertEq(storedBalance, 1, "Escrow deposit unsuccessful");
    }

     function test_depositAsset_ERC1155() public {
        uint256 tokenId = erc1155Mock.mint(address(borrower));

        borrower.approveERC1155(address(erc1155Mock));  

        borrower.deposit(CollateralType.ERC1155, address(erc1155Mock), 1, tokenId);

        uint256 storedBalance = borrower.getBalance(address(erc1155Mock));

        assertEq(storedBalance, 1, "Escrow deposit unsuccessful");
    }
}

contract User {
    CollateralEscrowV1 public escrow;
   

    constructor(UpgradeableBeacon escrowBeacon, address _wethMock, address _erc721Mock, address _erc1155Mock) {
        // Deploy escrow
        BeaconProxy proxy_ = new BeaconProxy(
            address(escrowBeacon),
            abi.encodeWithSelector(CollateralEscrowV1.initialize.selector, 0)
        );
        escrow = CollateralEscrowV1(address(proxy_));
       
    }

    function getEscrow() public view returns (CollateralEscrowV1) {
        return escrow;
    }

    function deposit(
        CollateralType _collateralType,
        address _collateralAddress,
        uint256 _amount,
        uint256 _tokenId
    ) public {
        escrow.depositAsset(
            _collateralType,
            _collateralAddress,
            _amount,
            _tokenId
        );
    }


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
