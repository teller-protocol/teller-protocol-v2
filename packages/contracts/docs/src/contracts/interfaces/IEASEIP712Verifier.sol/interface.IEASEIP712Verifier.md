# IEASEIP712Verifier
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/interfaces/IEASEIP712Verifier.sol)


## Functions
### getNonce

*Returns the current nonce per-account.*


```solidity
function getNonce(address account) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The requested accunt.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current nonce.|


### attest

*Verifies signed attestation.*


```solidity
function attest(
    address recipient,
    bytes32 schema,
    uint256 expirationTime,
    bytes32 refUUID,
    bytes calldata data,
    address attester,
    uint8 v,
    bytes32 r,
    bytes32 s
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The recipient of the attestation.|
|`schema`|`bytes32`|The UUID of the AS.|
|`expirationTime`|`uint256`|The expiration time of the attestation.|
|`refUUID`|`bytes32`|An optional related attestation's UUID.|
|`data`|`bytes`|Additional custom data.|
|`attester`|`address`|The attesting account.|
|`v`|`uint8`|The recovery ID.|
|`r`|`bytes32`|The x-coordinate of the nonce R.|
|`s`|`bytes32`|The signature data.|


### revoke

*Verifies signed revocations.*


```solidity
function revoke(bytes32 uuid, address attester, uint8 v, bytes32 r, bytes32 s) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`uuid`|`bytes32`|The UUID of the attestation to revoke.|
|`attester`|`address`|The attesting account.|
|`v`|`uint8`|The recovery ID.|
|`r`|`bytes32`|The x-coordinate of the nonce R.|
|`s`|`bytes32`|The signature data.|


