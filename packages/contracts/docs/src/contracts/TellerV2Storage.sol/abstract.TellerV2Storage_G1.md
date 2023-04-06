# TellerV2Storage_G1
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/TellerV2Storage.sol)

**Inherits:**
[TellerV2Storage_G0](/contracts/TellerV2Storage.sol/abstract.TellerV2Storage_G0.md)


## State Variables
### _trustedMarketForwarders

```solidity
mapping(uint256 => address) internal _trustedMarketForwarders;
```


### _approvedForwarderSenders

```solidity
mapping(address => EnumerableSet.AddressSet) internal _approvedForwarderSenders;
```


