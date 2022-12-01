// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "./Testable.sol";
import "@mangrovedao/hardhat-test-solidity/test.sol";

import { CollateralEscrowFactory } from "../escrow/CollateralEscrowFactory.sol";
import { CollateralEscrowV1 } from "../escrow/CollateralEscrowV1.sol";
import "../mock/WethMock.sol";
import "../interfaces/escrow/ICollateralEscrowFactory.sol";
import "../interfaces/escrow/ICollateralEscrowV1.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract CollateralEscrowFactory_Test is Testable {
    User private borrower;
    CollateralEscrowFactory private collateralFactory;
    WethMock wethMock;

    function setup_beforeAll() public {
        borrower = new User();
        wethMock = new WethMock();
        // Deploy implementation
        CollateralEscrowV1 escrowImplementation = new CollateralEscrowV1();
        // Deploy beacon contract with implementation
        UpgradeableBeacon escrowBeacon =
            new UpgradeableBeacon(address(escrowImplementation));
        // Deploy factory contract with beacon address
        collateralFactory = new CollateralEscrowFactory(address(escrowBeacon));
    }

    function createEscrow_test() public {
        uint256 bidId = 29;
        // Deploy escrow
        address deployedEscrow = borrower.deployCollateralEscrow(address(collateralFactory), bidId);
        // Get created escrow bidId
        uint256 createdEscrowBidId = CollateralEscrowV1(deployedEscrow).bidId();
        Test.eq(
            createdEscrowBidId,
            bidId,
            'Escrow was not created'
        );
        // Get stored escrow from factory
        address storedEscrow = collateralFactory.getEscrow(bidId);
        Test.eq(
            storedEscrow,
            deployedEscrow,
            'Created escrow was not stored'
        );
    }

    function validateCollateral_test() public {
        ICollateralEscrowFactory.Collateral memory collateralInfo;
        collateralInfo._collateralType = ICollateralEscrowFactory.CollateralType.ERC20;
        collateralInfo._amount = 1000;
        collateralInfo._tokenId = 0;
        uint256 balance = wethMock.balanceOf(address(borrower));
        bool validation = collateralFactory.validateCollateral(
            15,
            address(0),
            address(wethMock),
            collateralInfo
        );
        Test.eq(
            validation,
            false,
            'Incorrect collateral validation'
        );
    }
}

contract User {
    constructor() {}

    function deployCollateralEscrow(
        address collateralEscrowFactory,
        uint256 bidId
    ) public returns(address) {
        return ICollateralEscrowFactory(collateralEscrowFactory)
            .deployCollateralEscrow(bidId);
    }

}