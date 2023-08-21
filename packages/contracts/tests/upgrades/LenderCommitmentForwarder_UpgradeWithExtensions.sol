// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "../Testable.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../../contracts/LenderCommitmentForwarder.sol";
 
import "../../contracts/LenderCommitmentForwarder_V2.sol";
contract LenderCommitmentForwarder_UpgradeToV2 is Testable {
    ProxyAdmin internal admin;
    TransparentUpgradeableProxy internal proxy;

    address internal constant tellerV2 = address(1);
    address internal constant marketRegistry = address(2);

    LenderCommitmentForwarder internal logicV1 =
        new LenderCommitmentForwarder(tellerV2, marketRegistry);
     LenderCommitmentForwarder_V2 internal logicV2 =
        new LenderCommitmentForwarder_V2(tellerV2, marketRegistry);

    function setUp() public {
        admin = new ProxyAdmin();
        proxy = new TransparentUpgradeableProxy(
            address(logicV1),
            address(admin),
            ""
        );

        // Create 2 commitments to test the ID being incremented
        assertEq(_createCommitment(), 0, "Commitment ID should be 0");
        assertEq(_createCommitment(), 1, "Commitment ID should be 1");
    }

    function _createCommitment() internal returns (uint256 commitmentId_) {
        LenderCommitmentForwarder.Commitment memory commitment;
        commitment.marketId = 1;
        commitment.principalTokenAddress = address(123);
        commitment.maxPrincipal = 10_000_000;
        commitment.maxDuration = 60 days;
        commitment.minInterestRate = 100;
        commitment.expiration = uint32(block.timestamp + 60 days);
        commitment.lender = address(this);

        address[] memory borrowers;
        commitmentId_ = LenderCommitmentForwarder(address(proxy))
            .createCommitment(commitment, borrowers);
    }

    function test_storage_slot_data_after_upgrade() public {
        // This should revert because the contract has not been upgraded yet with that function
        vm.expectRevert();
        LenderCommitmentForwarder_V2(address(proxy)).owner();

        // Upgrade contract to V2 and initialize owner
        admin.upgradeAndCall(
            proxy,
            address(logicV2),
            abi.encodeWithSelector(
                logicV2.initialize.selector,
                address(this)
            )
        );

        // Verify the owner is set to the correct address
        address owner = LenderCommitmentForwarder_V2(address(proxy))
            .owner();
        assertEq(
            owner,
            address(this),
            "Owner address should be set to this contract address"
        );

        // Verify the commitment principalTokenAddress is set to the correct address after the upgrade
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            address principalTokenAddress
        ) = LenderCommitmentForwarder_V2(address(proxy)).commitments(
                1
            );
        assertEq(
            principalTokenAddress,
            address(123),
            "Principal token address should be set to 123"
        );
    }
}
