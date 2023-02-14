pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

 
 
import "./MultiCollateralVault.sol";

contract MultiCollateralVaultFactory is OwnableUpgradeable {


    function createMultiCollateralVault() public {

        MultiCollateralVault vault = new MultiCollateralVault();

    }

}