pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "../interfaces/IMarketRegistry_V2.sol";
import { PaymentType } from "../libraries/V2Calculations.sol";

contract MarketRegistryMock is IMarketRegistry_V2 {
    //address marketOwner;

    address public globalMarketOwner;
    address public globalMarketFeeRecipient;
    bool public globalMarketsClosed;

    bool public globalBorrowerIsVerified = true;
    bool public globalLenderIsVerified = true;

    constructor() {}

   // function initialize(TellerAS _tellerAS) external {}

    function getCurrentTermsForMarket(uint256 _marketId) public view returns (bytes32){
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
        returns (bool isVerified_,bytes32)
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

    function getPaymentCycle(uint256 _marketId)
        public
        view
        returns (uint32, PaymentCycleType)
    {
        return (1000, PaymentCycleType.Seconds);
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

    function getMarketplaceFee(uint256 _marketId) public view returns (uint16) {
        return 1000;
    }

    function setMarketOwner(address _owner) public {
        globalMarketOwner = _owner;
    }

    function setMarketFeeRecipient(address _feeRecipient) public {
        globalMarketFeeRecipient = _feeRecipient;
    }


  function getMarketplaceFeeTerms(bytes32 _marketTermsId) public
        view
        
        returns ( address , uint16 )
    {

       

    }


    function getMarketTermsForLending(bytes32 _marketTermsId)
        public
        view
        
        returns ( uint32, PaymentCycleType, PaymentType, uint32, uint32 )
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


    function getPaymentType(uint256 _marketId)
        public
        view
        returns (PaymentType)
    {}

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
    ) public returns (uint256,bytes32) {}

  

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
