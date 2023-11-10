pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT
import "../interfaces/IMarketRegistry.sol";
import "../interfaces/IMarketRegistry_V2.sol";
import { PaymentType } from "../libraries/V2Calculations.sol";

contract MarketRegistryMock is IMarketRegistry, IMarketRegistry_V2 {
    //address marketOwner;

    address public globalMarketOwner;
    address public globalMarketFeeRecipient;
    bool public globalMarketsClosed;

    bool public globalBorrowerIsVerified = true;
    bool public globalLenderIsVerified = true;

    bytes32 public globalTermsForMarket;

    constructor() {}

    // function initialize(TellerAS _tellerAS) external {}

    function getCurrentTermsForMarket(uint256 _marketId)
        public
        view
        returns (bytes32)
    {
        return globalTermsForMarket;
    }

    function forceSetGlobalTermsForMarket(bytes32 _term) public {
        globalTermsForMarket = _term;
    }

    function isMarketOpen(uint256 _marketId) public view returns (bool) {
        return !globalMarketsClosed;
    }

    function isMarketClosed(uint256 _marketId) public view returns (bool) {
        return globalMarketsClosed;
    }

    function isVerifiedBorrower(uint256 _marketId, address _borrower)
        public
        view
        returns (bool isVerified_, bytes32)
    {
        isVerified_ = globalBorrowerIsVerified;
    }

    function isVerifiedLender(uint256 _marketId, address _lenderAddress)
        public
        view
        returns (bool isVerified_, bytes32)
    {
        isVerified_ = globalLenderIsVerified;
    }

    function getMarketOwner(uint256 _marketId)
        public
        view
        override
        returns (address)
    {
        return address(globalMarketOwner);
    }

    function getMarketFeeRecipient(uint256 _marketId)
        public
        view
        returns (address)
    {
        return address(globalMarketFeeRecipient);
    }

    function getMarketURI(uint256 _marketId)
        public
        view
        returns (string memory)
    {
        return "url://";
    }

    function getPaymentType(uint256 _marketId)
        public
        view
        returns (PaymentType)
    {
        return PaymentType.EMI;
    }

    function getPaymentCycleDuration(uint256 _marketId)
        public
        view
        returns (uint32)
    {
        return 1000;
    }

    function getPaymentCycleType(uint256 _marketId)
        external
        view
        returns (PaymentCycleType)
    {
        return PaymentCycleType.Seconds;
    }

    function getPaymentDefaultDuration(uint256 _marketId)
        public
        view
        returns (uint32)
    {
        return 1000;
    }

    function getBidExpirationTime(uint256 _marketId)
        public
        view
        returns (uint32)
    {
        return 1000;
    }

    //the current marketplace fee if a new loan is created   NOT for existing loans in this market
    function getMarketplaceFee(uint256 _marketId) public view returns (uint16) {
        return 1000;
    }

    function setMarketOwner(address _owner) public {
        globalMarketOwner = _owner;
    }

    function setMarketFeeRecipient(address _feeRecipient) public {
        globalMarketFeeRecipient = _feeRecipient;
    }

    function getMarketFeeTerms(bytes32 _marketTermsId)
        public
        view
        returns (address, uint16)
    {
        return (address(this), 2000);
    }

    function getMarketTermsForLending(bytes32 _marketTermsId)
        public
        view
        returns (uint32, PaymentCycleType, PaymentType, uint32, uint32)
    {
        return (2000, PaymentCycleType.Seconds, PaymentType.EMI, 4000, 5000);
    }

    function getBidExpirationTimeForTerms(bytes32 _marketTermsId)
        external
        view
        returns (uint32)
    {
        return 4000;
    }

    function getPaymentDefaultDurationForTerms(bytes32 _marketTermsId)
        external
        view
        returns (uint32)
    {
        return 6000;
    }

    function getPaymentTypeForTerms(bytes32 _marketTermsId)
        external
        view
        returns (PaymentType)
    {
        return PaymentType.EMI;
    }

    function getPaymentCycleTypeForTerms(bytes32 _marketTermsId)
        external
        view
        returns (PaymentCycleType)
    {
        return PaymentCycleType.Seconds;
    }

    function getPaymentCycleDurationForTerms(bytes32 _marketTermsId)
        external
        view
        returns (uint32)
    {
        return 3000;
    }

    function createMarket(
        address _initialOwner,
        bool _requireLenderAttestation,
        bool _requireBorrowerAttestation,
        string calldata _uri,
        MarketplaceTerms memory _marketTermsParams
    ) external returns (uint256 marketId_, bytes32 marketTerms_) {}

    function closeMarket(uint256 _marketId) public {}

    function mock_setGlobalMarketsClosed(bool closed) public {
        globalMarketsClosed = closed;
    }

    function mock_setBorrowerIsVerified(bool verified) public {
        globalBorrowerIsVerified = verified;
    }

    function mock_setLenderIsVerified(bool verified) public {
        globalLenderIsVerified = verified;
    }
}
