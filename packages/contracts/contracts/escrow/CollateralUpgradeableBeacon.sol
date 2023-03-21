

pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract CollateralUpgradeableBeacon is UpgradeableBeacon {


constructor(address _impl) UpgradeableBeacon(_impl) {}

}