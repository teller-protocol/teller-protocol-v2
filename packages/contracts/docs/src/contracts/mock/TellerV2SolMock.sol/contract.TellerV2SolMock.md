# TellerV2SolMock
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/mock/TellerV2SolMock.sol)

**Inherits:**
[ITellerV2](/contracts/interfaces/ITellerV2.sol/interface.ITellerV2.md), [TellerV2Storage](/contracts/TellerV2Storage.sol/abstract.TellerV2Storage.md)


## Functions
### setMarketRegistry


```solidity
function setMarketRegistry(address _marketRegistry) public;
```

### getMarketRegistry


```solidity
function getMarketRegistry() external view returns (IMarketRegistry);
```

### submitBid


```solidity
function submitBid(
    address _lendingToken,
    uint256 _marketId,
    uint256 _principal,
    uint32 _duration,
    uint16,
    string calldata,
    address _receiver
) public returns (uint256 bidId_);
```

### submitBid


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
) public returns (uint256 bidId_);
```

### repayLoanMinimum


```solidity
function repayLoanMinimum(uint256 _bidId) external;
```

### repayLoanFull


```solidity
function repayLoanFull(uint256 _bidId) external;
```

### repayLoan


```solidity
function repayLoan(uint256 _bidId, uint256 _amount) public;
```

### calculateAmountDue


```solidity
function calculateAmountDue(uint256 _bidId) public view returns (Payment memory due);
```

### calculateAmountDue

Calculates the minimum payment amount due for a loan at a specific timestamp.


```solidity
function calculateAmountDue(uint256 _bidId, uint256 _timestamp) public view returns (Payment memory due);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bidId`|`uint256`|The id of the loan bid to get the payment amount for.|
|`_timestamp`|`uint256`|The timestamp at which to get the due payment at.|


### lenderAcceptBid


```solidity
function lenderAcceptBid(uint256 _bidId)
    public
    returns (uint256 amountToProtocol, uint256 amountToMarketplace, uint256 amountToBorrower);
```

### getBidState


```solidity
function getBidState(uint256 _bidId) public view virtual returns (BidState);
```

### getLoanDetails


```solidity
function getLoanDetails(uint256 _bidId) public view returns (LoanDetails memory);
```

### getBorrowerActiveLoanIds


```solidity
function getBorrowerActiveLoanIds(address _borrower) public view returns (uint256[] memory);
```

### isLoanDefaulted


```solidity
function isLoanDefaulted(uint256 _bidId) public view virtual returns (bool);
```

### isLoanLiquidateable


```solidity
function isLoanLiquidateable(uint256 _bidId) public view virtual returns (bool);
```

### isPaymentLate


```solidity
function isPaymentLate(uint256 _bidId) public view returns (bool);
```

### getLoanBorrower


```solidity
function getLoanBorrower(uint256 _bidId) external view virtual returns (address borrower_);
```

### getLoanLender


```solidity
function getLoanLender(uint256 _bidId) external view virtual returns (address lender_);
```

### getLoanMarketId


```solidity
function getLoanMarketId(uint256 _bidId) external view returns (uint256 _marketId);
```

### getLoanLendingToken


```solidity
function getLoanLendingToken(uint256 _bidId) external view returns (address token_);
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

### setLastRepaidTimestamp


```solidity
function setLastRepaidTimestamp(uint256 _bidId, uint32 _timestamp) public;
```

