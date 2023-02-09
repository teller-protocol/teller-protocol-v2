// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@mangrovedao/hardhat-test-solidity/test.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../TellerV2MarketForwarder.sol";
import { Testable } from "./Testable.sol";
import { LenderManager } from "../LenderManager.sol";

import "../mock/MarketRegistryMock.sol";

import { User } from "./Test_Helpers.sol";


contract LenderManager_Test is Testable, LenderManager {
    
    User private marketOwner;
    User private lender;
    User private borrower; 

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
       
        marketOwner = new User(address(mockTellerV2) );
        borrower = new User(address(mockTellerV2) );
        lender = new User(address(mockTellerV2) );

        mockMarketRegistry = new MarketRegistryMock(address(marketOwner));

       /* tester.__setMarketOwner(marketOwner);

        mockMarketRegistry.setMarketOwner(address(marketOwner));

        tokenAddress = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
        marketId = 2;
        maxAmount = 100000000000000000000;
        maxLoanDuration = 2480000;
        minInterestRate = 3000;
        expiration = uint32(block.timestamp) + uint32(64000);

        marketOwner.setTrustedMarketForwarder(marketId, address(this));
        lender.approveMarketForwarder(marketId, address(this));

        delete acceptBidWasCalled;
        delete submitBidWasCalled;*/
    }

    
 

    function acceptCommitment_test() public {
        
    }

}
 
/*
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

    function _updateCommitment(
        uint256 marketId,
        address tokenAddress,
        uint256 principal,
        uint32 loanDuration,
        uint16 interestRate,
        uint32 expiration
    ) public {
        commitmentForwarder.updateCommitment(
            marketId,
            tokenAddress,
            principal,
            loanDuration,
            interestRate,
            expiration
        );
    }

    function _acceptCommitment(
        uint256 marketId,
        address lender,
        address tokenAddress,
        uint256 principal,
        uint32 loanDuration,
        uint16 interestRate
    ) public returns (uint256) {
        return
            commitmentForwarder.acceptCommitment(
                marketId,
                lender,
                tokenAddress,
                principal,
                loanDuration,
                interestRate
            );
    }
}*/


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

/*
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
*/