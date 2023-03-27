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
import "../contracts/CollateralManager.sol";
 
contract CollateralManager_Override is CollateralManager {
    
    bool public checkBalancesWasCalled;
    bool public checkBalanceWasCalled; 



    function mock_deposit( uint256 _bidId, Collateral memory collateralInfo ) public {

        _deposit(_bidId, collateralInfo);
    }



    function _checkBalancesSuper(
         address _borrowerAddress,
        Collateral[] memory _collateralInfo,
        bool _shortCircut
    ) internal returns (bool validated_, bool[] memory checks_) {

       return super._checkBalances(
        _borrowerAddress,
       _collateralInfo,
       _shortCircut
       );

    }

    function _checkBalanceSuper(
        address _borrowerAddress,
        Collateral memory _collateralInfo
    ) internal returns (bool) {
       return super._checkBalance(_borrowerAddress,_collateralInfo);
    }

    /*
        Overrides
    */

    function _checkBalances(
        address _borrowerAddress,
        Collateral[] memory _collateralInfo,
        bool _shortCircut
    ) internal override returns (bool validated_, bool[] memory checks_) {

        checkBalancesWasCalled = true;

        validated_ = true;
        checks_ = new bool[](0);
    }
    


      function _checkBalance(
        address _borrowerAddress,
        Collateral memory _collateralInfo
    ) internal override returns (bool) {

        checkBalanceWasCalled = true;

        return true;
    }


 
}