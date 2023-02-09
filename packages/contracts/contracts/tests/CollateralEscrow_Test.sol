// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "./Testable.sol";
 

import { CollateralEscrowV1 } from "../escrow/CollateralEscrowV1.sol";
import "../mock/WethMock.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IWETH.sol";
import { CollateralType, CollateralEscrowV1 } from "../escrow/CollateralEscrowV1.sol";

contract CollateralEscrow_Test is Testable {
    BeaconProxy private proxy_;
    User private borrower;
    WethMock wethMock;
    uint256 amount = 1000;

    function setUp() public {
        // Deploy implementation
        CollateralEscrowV1 escrowImplementation = new CollateralEscrowV1();
        // Deploy beacon contract with implementation
        UpgradeableBeacon escrowBeacon = new UpgradeableBeacon(
            address(escrowImplementation)
        );
        // Deploy escrow
        wethMock = new WethMock();
        borrower = new User(escrowBeacon, address(wethMock));

        uint256 borrowerBalance = 50000;
        payable(address(borrower)).transfer(borrowerBalance);
        borrower.depositToWeth(borrowerBalance);
    }

    function test_depositAsset() public {
        _depositAsset();
    }

    function test_withdrawAsset() public {
        _depositAsset();

        borrower.withdraw(address(wethMock), amount, address(borrower));

        uint256 storedBalance = borrower.getBalance(address(wethMock));

        assertEq(storedBalance, 0,"Stored balance was not withdrawn");

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

    function _depositAsset() internal {
        borrower.approveWeth(amount);

        borrower.deposit(CollateralType.ERC20, address(wethMock), amount, 0);

        uint256 storedBalance = borrower.getBalance(address(wethMock));

        assertEq(storedBalance, amount, "Escrow deposit unsuccessful");
    }
}

contract User {
    CollateralEscrowV1 public escrow;
    address public immutable wethMock;

    constructor(UpgradeableBeacon escrowBeacon, address _wethMock) {
        // Deploy escrow
        BeaconProxy proxy_ = new BeaconProxy(
            address(escrowBeacon),
            abi.encodeWithSelector(CollateralEscrowV1.initialize.selector, 0)
        );
        escrow = CollateralEscrowV1(address(proxy_));
        wethMock = _wethMock;
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

    function withdraw(
        address _collateralAddress,
        uint256 _amount,
        address _recipient
    ) public {
        escrow.withdraw(_collateralAddress, _amount, _recipient);
    }

    function depositToWeth(uint256 amount) public {
        IWETH(wethMock).deposit{ value: amount }();
    }

    function approveWeth(uint256 amount) public {
        ERC20(wethMock).approve(address(escrow), amount);
    }

    function getBalance(address _collateralAddress)
        public
        returns (uint256 amount_)
    {
        (, amount_, , ) = escrow.collateralBalances(_collateralAddress);
    }

    receive() external payable {}
}
