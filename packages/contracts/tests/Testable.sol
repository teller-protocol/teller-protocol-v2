pragma solidity >=0.8.0 <0.9.0;

// SPDX-License-Identifier: MIT

import "forge-std/Test.sol";


abstract contract Testable is Test {
    receive() external payable {}
}
