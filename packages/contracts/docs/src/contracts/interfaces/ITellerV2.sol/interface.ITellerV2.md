# ITellerV2
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/interfaces/ITellerV2.sol)


## Functions
### submitBid

Function for a borrower to create a bid for a loan.


```solidity
function submitBid(
    address _lendingToken,
    uint256 _marketplaceId,
    uint256 _principal,
    uint32 _duration,
    uint16 _APR,
    string calldata _metadataURI,
    address _receiver
) external returns (uint256 bidId_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_lendingToken`|`address`|The lending token asset requested to be borrowed.|
|`_marketplaceId`|`uint256`|The unique id of the marketplace for the bid.|
|`_principal`|`uint256`|The principal amount of the loan bid.|
|`_duration`|`uint32`|The recurrent length of time before which a payment is due.|
|`_APR`|`uint16`|The proposed interest rate for the loan bid.|
|`_metadataURI`|`string`|The URI for additional borrower loan information as part of loan bid.|
|`_receiver`|`address`|The address where the loan amount will be sent to.|


### submitBid

Function for a borrower to create a bid for a loan with Collateral.


```solidity
function submitBid(
    address _lendingToken,
    uint256 _marketplaceId,
    uint256 _principal,
    uint32 _duration,
    uint16 _APR,
    string calldata _metadataURI,
    address _receiver,
    Collateral[] calldata _collateralInfo
) external returns (uint256 bidId_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_lendingToken`|`address`|The lending token asset requested to be borrowed.|
|`_marketplaceId`|`uint256`|The unique id of the marketplace for the bid.|
|`_principal`|`uint256`|The principal amount of the loan bid.|
|`_duration`|`uint32`|The recurrent length of time before which a payment is due.|
|`_APR`|`uint16`|The proposed interest rate for the loan bid.|
|`_metadataURI`|`string`|The URI for additional borrower loan information as part of loan bid.|
|`_receiver`|`address`|The address where the loan amount will be sent to.|
|`_collateralInfo`|`Collateral[]`|Additional information about the collateral asset.|


### lenderAcceptBid

Function for a lender to accept a proposed loan bid.


```solidity
function lenderAcceptBid(uint256 _bidId)
    external
    returns (uint256 amountToProtocol, uint256 amountToMarketplace, uint256 amountToBorrower);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bidId`|`uint256`|The id of the loan bid to accept.|


### calculateAmountDue


```solidity
function calculateAmountDue(uint256 _bidId) external view returns (Payment memory due);
```

### repayLoanMinimum

Function for users to make the minimum amount due for an active loan.


```solidity
function repayLoanMinimum(uint256 _bidId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bidId`|`uint256`|The id of the loan to make the payment towards.|


### repayLoanFull

Function for users to repay an active loan in full.


```solidity
function repayLoanFull(uint256 _bidId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bidId`|`uint256`|The id of the loan to make the payment towards.|


### repayLoan

Function for users to make a payment towards an active loan.


```solidity
function repayLoan(uint256 _bidId, uint256 _amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bidId`|`uint256`|The id of the loan to make the payment towards.|
|`_amount`|`uint256`|The amount of the payment.|


### isLoanDefaulted

Checks to see if a borrower is delinquent.


```solidity
function isLoanDefaulted(uint256 _bidId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bidId`|`uint256`|The id of the loan bid to check for.|


### isLoanLiquidateable

Checks to see if a loan was delinquent for longer than liquidation delay.


```solidity
function isLoanLiquidateable(uint256 _bidId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bidId`|`uint256`|The id of the loan bid to check for.|


### isPaymentLate

Checks to see if a borrower is delinquent.


```solidity
function isPaymentLate(uint256 _bidId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bidId`|`uint256`|The id of the loan bid to check for.|


### getBidState


```solidity
function getBidState(uint256 _bidId) external view returns (BidState);
```

### getBorrowerActiveLoanIds


```solidity
function getBorrowerActiveLoanIds(address _borrower) external view returns (uint256[] memory);
```

### getLoanBorrower

Returns the borrower address for a given bid.


```solidity
function getLoanBorrower(uint256 _bidId) external view returns (address borrower_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bidId`|`uint256`|The id of the bid/loan to get the borrower for.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`borrower_`|`address`|The address of the borrower associated with the bid.|


### getLoanLender

Returns the lender address for a given bid.


```solidity
function getLoanLender(uint256 _bidId) external view returns (address lender_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bidId`|`uint256`|The id of the bid/loan to get the lender for.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`lender_`|`address`|The address of the lender associated with the bid.|


### getLoanLendingToken


```solidity
function getLoanLendingToken(uint256 _bidId) external view returns (address token_);
```

### getLoanMarketId


```solidity
function getLoanMarketId(uint256 _bidId) external view returns (uint256);
```

### getLoanSummary


```solidity
function getLoanSummary(uint256 _bidId)
    external
    view
    returns (
        address borrower,
        address lender,
        uint256 marketId,
        address principalTokenAddress,
        uint256 principalAmount,
        uint32 acceptedTimestamp,
        BidState bidState
    );
```

