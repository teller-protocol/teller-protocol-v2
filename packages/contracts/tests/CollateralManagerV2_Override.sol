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
import "../contracts/CollateralManagerV2.sol";

contract CollateralManagerV2_Override is CollateralManagerV2 {
    bool public checkBalancesWasCalled;
    bool public checkBalanceWasCalled;
    address public withdrawInternalWasCalledToRecipient;
    bool public commitCollateralInternalWasCalled;

    bool bidsCollateralBackedGlobally;
    bool public checkBalanceGlobalValid = true;
 
    bool public depositWasCalled;
    bool public withdrawWasCalled;

    //force adds collateral info for a bid even if it doesnt exist (for testing)
    function commitCollateralSuper(
        uint256 bidId,
        Collateral memory collateralInfo
    ) public {
        super._commitCollateral(bidId, collateralInfo);
    }

/*
    function _depositSuper(uint256 _bidId, Collateral memory _collateralInfo)
        public
    {
        super._deposit(_bidId, _collateralInfo);
    }*/

    function _withdrawSuper(uint256 _bidId, address _receiver) public {
        super._withdraw(_bidId, _receiver);
    }

    function _commitCollateralSuper(
        uint256 _bidId,
        Collateral memory _collateralInfo
    ) public {
        super._commitCollateral(_bidId, _collateralInfo);
    }

    function isBidCollateralBackedSuper(uint256 _bidId) public returns (bool) {
        return super.isBidCollateralBacked(_bidId);
    }

    function _checkBalancesSuper(
        address _borrowerAddress,
        Collateral[] memory _collateralInfo,
        bool _shortCircut
    ) public returns (bool validated_, bool[] memory checks_) {
        return
            super._checkBalances(
                _borrowerAddress,
                _collateralInfo,
                _shortCircut
            );
    }

    function _checkBalanceSuper(
        address _borrowerAddress,
        Collateral memory _collateralInfo
    ) public returns (bool) {
        return super._checkBalance(_borrowerAddress, _collateralInfo);
    }

    function setBidsCollateralBackedGlobally(bool _backed) public {
        bidsCollateralBackedGlobally = _backed;
    }
 
 
    function setCheckBalanceGlobalValid(bool _valid) public {
        checkBalanceGlobalValid = _valid;
    }

    /*
        Overrides
    */

    function isBidCollateralBacked(uint256 _bidId)
        public view
        override
        returns (bool)
    {
        return bidsCollateralBackedGlobally;
    }

    function _checkBalances(
        address _borrowerAddress,
        Collateral[] memory _collateralInfo,
        bool _shortCircut
    ) internal override returns (bool validated_, bool[] memory checks_) {
        checkBalancesWasCalled = true;

        validated_ = checkBalanceGlobalValid;
        checks_ = new bool[](0);
    }

    function _deposit(uint256 _bidId, Collateral memory collateralInfo)
        internal
        
    {
        depositWasCalled = true;
    }

    function _checkBalance(
        address _borrowerAddress,
        Collateral memory _collateralInfo
    ) internal override returns (bool) {
        checkBalanceWasCalled = true;

        return checkBalanceGlobalValid;
    }

   
   

    function _withdraw(uint256 _bidId, address recipient) internal override {
        withdrawInternalWasCalledToRecipient = recipient;
        withdrawWasCalled = true;
    }

    function _commitCollateral(
        uint256 _bidId,
        Collateral memory _collateralInfo
    ) internal override {
        commitCollateralInternalWasCalled = true;
    }
}