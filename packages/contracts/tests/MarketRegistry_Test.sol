// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "./Testable.sol";

import { TellerV2 } from "../contracts/TellerV2.sol";
import { MarketRegistry } from "../contracts/MarketRegistry.sol";
import { ReputationManager } from "../contracts/ReputationManager.sol";

import "../contracts/TellerV2Storage.sol";

import "../contracts/interfaces/IMarketRegistry.sol";
import "../contracts/interfaces/IReputationManager.sol";

import "../contracts/EAS/TellerAS.sol";

import "../contracts/mock/WethMock.sol";
import "../contracts/interfaces/IWETH.sol";

import { User } from "./Test_Helpers.sol";
import { PaymentType } from "../contracts/libraries/V2Calculations.sol";

contract MarketRegistry_Test is Testable, TellerV2 {
    User private marketOwner;
    User private borrower;
    User private lender;

    WethMock wethMock;

    constructor() TellerV2(address(address(0))) {}

    function setUp() public {
        wethMock = new WethMock();

        marketOwner = new User(this, wethMock);
        borrower = new User(this, wethMock);
        lender = new User(this, wethMock);

        lenderCommitmentForwarder = address(0);
        marketRegistry = IMarketRegistry(new MarketRegistry());
        reputationManager = IReputationManager(new ReputationManager());

        marketOwner.createMarket(
            address(marketRegistry),
            8000,
            7000,
            5000,
            500,
            false,
            false,
            PaymentType.EMI,
            "uri://"
        );
    }
}
