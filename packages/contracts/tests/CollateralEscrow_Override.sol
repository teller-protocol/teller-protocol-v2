// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Testable } from "./Testable.sol";

import { CollateralEscrowV1 } from "../contracts/escrow/CollateralEscrowV1.sol";
import "../contracts/mock/WethMock.sol";
 

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/interfaces/IWETH.sol";
import { CollateralType, CollateralEscrowV1 } from "../contracts/escrow/CollateralEscrowV1.sol";

contract CollateralEscrow_Override is CollateralEscrowV1 {
     
}
