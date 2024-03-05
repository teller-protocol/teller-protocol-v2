// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import { PaymentType, PaymentCycleType } from "../libraries/V2Calculations.sol";

import { IMarketRegistry } from "./IMarketRegistry.sol";

interface IMarketRegistry_V2 is IMarketRegistry {
    struct MarketplaceTerms {
        uint16 marketplaceFeePercent; // 10000 is 100%
        PaymentType paymentType;
        PaymentCycleType paymentCycleType;
        uint32 paymentCycleDuration; // unix time (seconds)
        uint32 paymentDefaultDuration; //unix time
        uint32 bidExpirationTime; //unix time
        address feeRecipient;
    }

    function getMarketTermsForLending(bytes32 _marketTermsId)
        external
        view
        returns (uint32, PaymentCycleType, PaymentType, uint32, uint32);

    function getMarketFeeTerms(bytes32 _marketTermsId)
        external
        view
        returns (address, uint16);

    function getBidExpirationTimeForTerms(bytes32 _marketTermsId)
        external
        view
        returns (uint32);

    function getPaymentDefaultDurationForTerms(bytes32 _marketTermsId)
        external
        view
        returns (uint32);

    function getPaymentTypeForTerms(bytes32 _marketTermsId)
        external
        view
        returns (PaymentType);

    function getPaymentCycleTypeForTerms(bytes32 _marketTermsId)
        external
        view
        returns (PaymentCycleType);

    function getPaymentCycleDurationForTerms(bytes32 _marketTermsId)
        external
        view
        returns (uint32);

    function getPaymentCycleType(uint256 _marketId)
        external
        view
        returns (PaymentCycleType);

    function getPaymentCycleDuration(uint256 _marketId)
        external
        view
        returns (uint32);

    function createMarket(
        address _initialOwner,
        bool _requireLenderAttestation,
        bool _requireBorrowerAttestation,
        string calldata _uri,
        MarketplaceTerms memory _marketTermsParams
    ) external returns (uint256 marketId_, bytes32 marketTerms_);

    function getCurrentTermsForMarket(uint256 _marketId)
        external
        view
        returns (bytes32);
}
