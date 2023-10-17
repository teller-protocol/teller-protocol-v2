// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

 import { IMarketRegistry } from "./IMarketRegistry.sol";
import { PaymentType, PaymentCycleType } from "../libraries/V2Calculations.sol";

interface IMarketRegistry_V2 is IMarketRegistry {
    

   

     
    function getMarketURI(uint256 _marketId)
        external
        view
        returns (string memory);

    function getMarketTermsForLending(bytes32 _marketTermsId)
        external
        view
        
        returns ( uint32, PaymentCycleType, PaymentType, uint32, uint32 );
   
    function getMarketplaceFeeTerms(bytes32 _marketTermsId) 
        external
        view
        
        returns ( address , uint16 ) ;


   /* function getMarketFeeRecipient(uint256 _marketId)
        external
        view
        returns (address);*/

    

    /*function getPaymentCycle(uint256 _marketId)
        external
        view
        returns (uint32, PaymentCycleType);*/

    /*function getPaymentDefaultDuration(uint256 _marketId)
        external
        view
        returns (uint32);*/

    /*function getBidExpirationTime(uint256 _marketId)
        external
        view
        returns (uint32);*/

    
    /*function getPaymentType(uint256 _marketId)
        external
        view
        returns (PaymentType);*/

   

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
    ) external returns (uint256 marketId_,
     bytes32 marketTerms_);
     
 
    function closeMarket(uint256 _marketId) external;

    function getCurrentTermsForMarket(uint256 _marketId) external view returns (bytes32);
}
