// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IMarketRegistry } from "./IMarketRegistry.sol";
import { PaymentType, PaymentCycleType } from "../libraries/V2Calculations.sol";

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

    function getMarketURI(uint256 _marketId)
        external
        view
        returns (string memory);

    function getMarketTermsForLending(bytes32 _marketTermsId)
        external
        view
        returns (uint32, PaymentCycleType, PaymentType, uint32, uint32);

    function getMarketplaceFeeTerms(bytes32 _marketTermsId)
        external
        view
        returns (address, uint16);

    function getBidExpirationTime(bytes32 _marketTermsId)
        external
        view
        returns (uint32);

    function getPaymentDefaultDuration(bytes32 _marketTermsId)
        external
        view
        returns (uint32);

    function getPaymentType(bytes32 _marketTermsId)
        external
        view
        returns (PaymentType);

    function getPaymentCycleType(bytes32 _marketTermsId)
        external
        view
        returns (PaymentCycleType);

    function getPaymentCycleDuration(bytes32 _marketTermsId)
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

    function closeMarket(uint256 _marketId) external;

    function getCurrentTermsForMarket(uint256 _marketId)
        external
        view
        returns (bytes32);
}
