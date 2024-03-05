// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../EAS/TellerAS.sol";
import { PaymentType, PaymentCycleType } from "../libraries/V2Calculations.sol";

import { IMarketRegistry } from "./IMarketRegistry.sol";

interface IMarketRegistry_V1 is IMarketRegistry {
    function initialize(TellerAS tellerAs) external;

    function createMarket(
        address _initialOwner,
        uint32 _paymentCycleDuration,
        uint32 _paymentDefaultDuration,
        uint32 _bidExpirationTime,
        uint16 _feePercent,
        bool _requireLenderAttestation,
        bool _requireBorrowerAttestation,
        PaymentType _paymentType,
        PaymentCycleType _paymentCycleType,
        string calldata _uri
    ) external returns (uint256 marketId_);

    function createMarket(
        address _initialOwner,
        uint32 _paymentCycleDuration,
        uint32 _paymentDefaultDuration,
        uint32 _bidExpirationTime,
        uint16 _feePercent,
        bool _requireLenderAttestation,
        bool _requireBorrowerAttestation,
        string calldata _uri
    ) external returns (uint256 marketId_);

    function getPaymentCycle(uint256 _marketId)
        external
        view
        returns (uint32, PaymentCycleType);
}
