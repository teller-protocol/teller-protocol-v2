// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@mangrovedao/hardhat-test-solidity/test.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../TellerV2MarketForwarder.sol";
import { Testable } from "./Testable.sol";
import { LenderManager } from "../LenderManager.sol";

import "../mock/MarketRegistryMock.sol";

import { User } from "./Test_Helpers.sol";


contract LenderManager_Test is Testable, LenderManager {
    
    LenderManagerUser private marketOwner;
    LenderManagerUser private lender;
    LenderManagerUser private borrower; 

    LenderCommitmentTester mockTellerV2;
    MarketRegistryMock mockMarketRegistry;
 
    constructor()
        LenderManager(
            //address(0),
            address(new MarketRegistryMock(address(0)))
        )
    {}

    function setup_beforeAll() public {
        mockTellerV2 = new LenderCommitmentTester();
       
        marketOwner = new LenderManagerUser(address(mockTellerV2),address(this) );
        borrower = new LenderManagerUser(address(mockTellerV2),address(this) );
        lender = new LenderManagerUser(address(mockTellerV2),address(this) );

        mockMarketRegistry = new MarketRegistryMock(address(marketOwner));

       
    } 
    
 

    function registerLoan_test() public {
        uint256 bidId = 2;

        super.registerLoan(bidId,address(lender)); 
        
        Test.eq(super._exists(bidId), true, "Loan registration did not mint nft");
    }   



   function transferFrom_before() public {

        uint256 bidId = 2;

        super._mint(address(lender),bidId);

   }

   function transferFrom_test() public {

        uint256 bidId = 2;
        
        lender.transferLoan(bidId,address(borrower));
        
        Test.eq(super.ownerOf(bidId), address(borrower), "Loan nft was not transferred");
    }   

 
    //override
    function _hasMarketVerification(address _lender, uint256 _bidId)
     internal override view
     returns (bool){

        //hasMarketVerificationWasCalled = true;

        return true;
    }

    //should be able to test the negative case-- use foundry
     function _checkOwner() internal view override {
        // do nothing 
    }





}


contract LenderManagerUser is User{ 

    address lenderManager;
    constructor( address _tellerV2, address _lenderManager) User(_tellerV2) { 
        lenderManager=_lenderManager;
     }


    function transferLoan(uint256 bidId, address to) public {
        IERC721(lenderManager).transferFrom(address(this),to,bidId);
    }
 

}
  


//Move to a helper  or change it 
contract LenderCommitmentTester is TellerV2Context {
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
 