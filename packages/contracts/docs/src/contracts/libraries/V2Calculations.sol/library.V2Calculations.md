# V2Calculations
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/libraries/V2Calculations.sol)


## Functions
### lastRepaidTimestamp

Returns the timestamp of the last payment made for a loan.


```solidity
function lastRepaidTimestamp(Bid storage _bid) internal view returns (uint32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bid`|`Bid`|The loan bid struct to get the timestamp for.|


### calculateAmountOwed

Calculates the amount owed for a loan.


```solidity
function calculateAmountOwed(Bid storage _bid, uint256 _timestamp, PaymentCycleType _paymentCycleType)
    internal
    view
    returns (uint256 owedPrincipal_, uint256 duePrincipal_, uint256 interest_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bid`|`Bid`|The loan bid struct to get the owed amount for.|
|`_timestamp`|`uint256`|The timestamp at which to get the owed amount at.|
|`_paymentCycleType`|`PaymentCycleType`|The payment cycle type of the loan (Seconds or Monthly).|


### calculateAmountOwed


```solidity
function calculateAmountOwed(
    Bid storage _bid,
    uint256 _lastRepaidTimestamp,
    uint256 _timestamp,
    PaymentCycleType _paymentCycleType
) internal view returns (uint256 owedPrincipal_, uint256 duePrincipal_, uint256 interest_);
```

### calculatePaymentCycleAmount

Calculates the amount owed for a loan for the next payment cycle.


```solidity
function calculatePaymentCycleAmount(
    PaymentType _type,
    PaymentCycleType _cycleType,
    uint256 _principal,
    uint32 _duration,
    uint32 _paymentCycle,
    uint16 _apr
) internal returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_type`|`PaymentType`|The payment type of the loan.|
|`_cycleType`|`PaymentCycleType`|The cycle type set for the loan. (Seconds or Monthly)|
|`_principal`|`uint256`|The starting amount that is owed on the loan.|
|`_duration`|`uint32`|The length of the loan.|
|`_paymentCycle`|`uint32`|The length of the loan's payment cycle.|
|`_apr`|`uint16`|The annual percentage rate of the loan.|


