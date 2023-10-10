// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "./Testable.sol";

import { CollateralEscrowV1 } from "../contracts/escrow/CollateralEscrowV1.sol";
import "../contracts/mock/WethMock.sol";
 

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./tokens/TestERC20Token.sol";
import "./tokens/TestERC721Token.sol";
import "./tokens/TestERC1155Token.sol";

import "../contracts/mock/TellerV2SolMock.sol";
import "../contracts/CollateralManagerV2.sol";

import "./CollateralManagerV2_Override.sol";

import "../../util/IntegrationSetup.sol";


/*


TODO
 
 add a test that verifies that you can use 2 NFT from the same project 
 as collateral for a single loan 


get test coverage up to 80 

*/
contract CollateralManagerV2_Fork_Test is Testable, IntegrationSetup {
    CollateralManagerV2_Override collateralManager;
    User private borrower;
    User private lender;
    User private liquidator;

    TestERC20Token wethMock;
    TestERC721Token erc721Mock;
    TestERC1155Token erc1155Mock;

    //TellerV2_Mock tellerV2Mock;
 

    event CollateralCommitted(
        uint256 _bidId,
        CollateralType _type,
        address _collateralAddress,
        uint256 _amount,
        uint256 _tokenId
    );
    event CollateralClaimed(uint256 _bidId);
    event CollateralDeposited(
        uint256 _bidId,
        CollateralType _type,
        address _collateralAddress,
        uint256 _amount,
        uint256 _tokenId
    );
    event CollateralWithdrawn(
        uint256 _bidId,
        CollateralType _type,
        address _collateralAddress,
        uint256 _amount,
        uint256 _tokenId,
        address _recipient
    );

    function setUp() public {
        

        wethMock = new TestERC20Token("wrappedETH", "WETH", 1e24, 18);
        erc721Mock = new TestERC721Token("ERC721", "ERC721");
        erc1155Mock = new TestERC1155Token("ERC1155");

        
        borrower = new User();
        lender = new User();
        liquidator = new User();



        //  uint256 borrowerBalance = 50000;
        //   payable(address(borrower)).transfer(borrowerBalance);

        /*
        tellerV2Mock = new TellerV2_Mock();
        collateralManager = new CollateralManagerV2_Override();

        collateralManager.initialize( 
            address(tellerV2Mock)
        );
        */
  
            


         super.setUp();


         //make some bids here, then perform the upgrade (sim) 

         
    }

    function test_initialize_valid() public {
        
 
    }
 
 
   
 
 
}

contract User {
    constructor() {}

  

    receive() external payable {}

    //receive 721
    function onERC721Received(address, address, uint256, bytes calldata)
        external
        returns (bytes4)
    {
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
  