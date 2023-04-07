// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { Testable } from "./Testable.sol";
import { TellerV2Context } from "../contracts/TellerV2Context.sol";
import { IMarketRegistry } from "../contracts/interfaces/IMarketRegistry.sol";
import { TellerV2MarketForwarder } from "../contracts/TellerV2MarketForwarder.sol";

import { User } from "./Test_Helpers.sol";

import "../contracts/mock/MarketRegistryMock.sol";

contract MarketForwarder_Override is TellerV2MarketForwarder {
    constructor(address tellerV2, address marketRegistry)
        TellerV2MarketForwarder(tellerV2, marketRegistry)
    {}

    function forwardCall(bytes memory _data, address _msgSender)
        public
        returns (bytes memory)
    {
        return super._forwardCall(_data, _msgSender);
    }
}
