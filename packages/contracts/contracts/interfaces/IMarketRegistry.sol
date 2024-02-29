// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { PaymentType, PaymentCycleType } from "../libraries/V2Calculations.sol";


interface IMarketRegistry {
    function isMarketOpen(uint256 _marketId) external view returns (bool);

    function isMarketClosed(uint256 _marketId) external view returns (bool);

    function getMarketOwner(uint256 _marketId) external view returns (address);

    function closeMarket(uint256 _marketId) external;

    function getMarketFeeRecipient(uint256 _marketId)
        external
        view
        returns (address);

    function getMarketURI(uint256 _marketId)
        external
        view
        returns (string memory);

    

    function getPaymentDefaultDuration(uint256 _marketId)
        external
        view
        returns (uint32);

    function getBidExpirationTime(uint256 _marketId)
        external
        view
        returns (uint32);

    function getPaymentType(uint256 _marketId)
        external
        view
        returns (PaymentType);


    function getMarketplaceFee(uint256 _marketId)
        external
        view
        returns (uint16);

    function isVerifiedBorrower(uint256 _marketId, address _borrower)
        external
        view
        returns (bool, bytes32);

    function isVerifiedLender(uint256 _marketId, address _lender)
        external
        view
        returns (bool, bytes32);


}
