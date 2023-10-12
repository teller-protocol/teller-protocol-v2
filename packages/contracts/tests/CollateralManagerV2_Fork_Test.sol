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

import "./integration/IntegrationFork.sol";


import "../contracts/interfaces/IWETH.sol";
 
/*


TODO
 
 add a test that verifies that you can use 2 NFT from the same project 
 as collateral for a single loan 


get test coverage up to 80 

*/
contract CollateralManagerV2_Fork_Test is Testable, IntegrationForkSetup {
    CollateralManagerV2_Override collateralManagerV2;
    //User private borrower;
    //User private lender;
    address liquidator;

    TestERC20Token wethMock;
    TestERC721Token erc721Mock;
    TestERC1155Token erc1155Mock;

    //TellerV2_Mock tellerV2Mock;
   


    uint256 preUpgradeBidId;

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

    function setUp() public override {
        wethMock = new TestERC20Token("wrappedETH", "WETH", 1e24, 18);
        erc721Mock = new TestERC721Token("ERC721", "ERC721");
        erc1155Mock = new TestERC1155Token("ERC1155");

        borrower = address(new User());
        lender = address(new User());
        liquidator = address(new User());

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


        createPreUpgradeBidsForTests();




        //need to deploy our new version of TellerV2  locally 

        address metaForwarder = address(0); //for this test 

        TellerV2 updatedTellerV2_impl = new TellerV2(metaForwarder);

        //override the old tellerv2 with the new impl 
        vm.etch(address(tellerV2), address(updatedTellerV2_impl).code);


        collateralManagerV2 = new CollateralManagerV2_Override();
        collateralManagerV2.initialize( 
            address(tellerV2)
        );


        //call the reinitializer on our upgraded tellerv2 to set collateral manager v2 
        TellerV2(address(tellerV2)).setCollateralManagerV2(address(collateralManagerV2));
    


    }


    function createPreUpgradeBidsForTests() public {

        //this works 

        address lendingToken = address(wethMock);
        uint256 marketplaceId = 1;
        uint256 principal = 100;
        uint32 duration = 50000000;
        uint16 apr = 100;
        string memory metadataURI = "";
        address receiver = address(borrower);
        

        vm.prank(address(borrower));
        preUpgradeBidId = ITellerV2(tellerV2).submitBid(
            lendingToken,
            marketplaceId,
            principal,
            duration,
            apr,
            metadataURI,
            receiver 
        );


    } 

    function test_legacy_bid_can_be_accepted_after_upgrade() public {

        uint256 bidId = preUpgradeBidId;

        vm.prank(address(lender));

        ITellerV2(tellerV2).lenderAcceptBid(bidId);

        //assertions can be made  

    }


    function test_legacy_bid_can_be_paid_withdrawn_after_upgrade() public {


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
