pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT
import "../interfaces/IMarketRegistry.sol";
import "../interfaces/IMarketRegistry_V2.sol";
import { PaymentType } from "../libraries/V2Calculations.sol";

contract MarketRegistryMock is IMarketRegistry,IMarketRegistry_V2 {
    //address marketOwner;

    address public globalMarketOwner;
    address public globalMarketFeeRecipient;
    bool public globalMarketsClosed;

    bool public globalBorrowerIsVerified = true;
    bool public globalLenderIsVerified = true;

    constructor() {}

    // function initialize(TellerAS _tellerAS) external {}

    function getCurrentTermsForMarket(uint256 _marketId)
        public
        view
        returns (bytes32)
    {
        //impl me !
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
    returns (PaymentCycleType){
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
    {}

    function getMarketTermsForLending(bytes32 _marketTermsId)
        public
        view
        returns (uint32, PaymentCycleType, PaymentType, uint32, uint32)
    {
        //require(_marketTermsId != bytes32(0), "Invalid market terms." );
        /*return (
            marketTerms[_marketTermsId].paymentCycleDuration,
            marketTerms[_marketTermsId].paymentCycleType,
            marketTerms[_marketTermsId].paymentType,
            marketTerms[_marketTermsId].paymentDefaultDuration,
            marketTerms[_marketTermsId].bidExpirationTime
        );*/
    }

    function getBidExpirationTimeForTerms(bytes32 _marketTermsId)
        external
        view
        returns (uint32)
    {}

    function getPaymentDefaultDurationForTerms(bytes32 _marketTermsId)
        external
        view
        returns (uint32)
    {}

    function getPaymentTypeForTerms(bytes32 _marketTermsId)
        external
        view
        returns (PaymentType)
    {}

    function getPaymentCycleTypeForTerms(bytes32 _marketTermsId)
        external
        view
        returns (PaymentCycleType)
    {}

    function getPaymentCycleDurationForTerms(bytes32 _marketTermsId)
        external
        view
        returns (uint32)
    {}


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
