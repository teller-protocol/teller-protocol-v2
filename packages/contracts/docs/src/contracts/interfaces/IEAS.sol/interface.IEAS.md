# IEAS
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/interfaces/IEAS.sol)


## Functions
### getASRegistry

*Returns the address of the AS global registry.*


```solidity
function getASRegistry() external view returns (IASRegistry);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IASRegistry`|The address of the AS global registry.|


### getEIP712Verifier

*Returns the address of the EIP712 verifier used to verify signed attestations.*


```solidity
function getEIP712Verifier() external view returns (IEASEIP712Verifier);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IEASEIP712Verifier`|The address of the EIP712 verifier used to verify signed attestations.|


### getAttestationsCount

*Returns the global counter for the total number of attestations.*


```solidity
function getAttestationsCount() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The global counter for the total number of attestations.|


### attest

*Attests to a specific AS.*


```solidity
function attest(address recipient, bytes32 schema, uint256 expirationTime, bytes32 refUUID, bytes calldata data)
    external
    payable
    returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The recipient of the attestation.|
|`schema`|`bytes32`|The UUID of the AS.|
|`expirationTime`|`uint256`|The expiration time of the attestation.|
|`refUUID`|`bytes32`|An optional related attestation's UUID.|
|`data`|`bytes`|Additional custom data.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The UUID of the new attestation.|


### attestByDelegation

*Attests to a specific AS using a provided EIP712 signature.*


```solidity
function attestByDelegation(
    address recipient,
    bytes32 schema,
    uint256 expirationTime,
    bytes32 refUUID,
    bytes calldata data,
    address attester,
    uint8 v,
    bytes32 r,
    bytes32 s
) external payable returns (bytes32);
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

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The UUID of the new attestation.|


### revoke

*Revokes an existing attestation to a specific AS.*


```solidity
function revoke(bytes32 uuid) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`uuid`|`bytes32`|The UUID of the attestation to revoke.|


### revokeByDelegation

*Attests to a specific AS using a provided EIP712 signature.*


```solidity
function revokeByDelegation(bytes32 uuid, address attester, uint8 v, bytes32 r, bytes32 s) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`uuid`|`bytes32`|The UUID of the attestation to revoke.|
|`attester`|`address`|The attesting account.|
|`v`|`uint8`|The recovery ID.|
|`r`|`bytes32`|The x-coordinate of the nonce R.|
|`s`|`bytes32`|The signature data.|


### getAttestation

*Returns an existing attestation by UUID.*


```solidity
function getAttestation(bytes32 uuid) external view returns (Attestation memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`uuid`|`bytes32`|The UUID of the attestation to retrieve.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Attestation`|The attestation data members.|


### isAttestationValid

*Checks whether an attestation exists.*


```solidity
function isAttestationValid(bytes32 uuid) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`uuid`|`bytes32`|The UUID of the attestation to retrieve.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether an attestation exists.|


### isAttestationActive

*Checks whether an attestation is active.*


```solidity
function isAttestationActive(bytes32 uuid) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`uuid`|`bytes32`|The UUID of the attestation to retrieve.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether an attestation is active.|


### getReceivedAttestationUUIDs

*Returns all received attestation UUIDs.*


```solidity
function getReceivedAttestationUUIDs(
    address recipient,
    bytes32 schema,
    uint256 start,
    uint256 length,
    bool reverseOrder
) external view returns (bytes32[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The recipient of the attestation.|
|`schema`|`bytes32`|The UUID of the AS.|
|`start`|`uint256`|The offset to start from.|
|`length`|`uint256`|The number of total members to retrieve.|
|`reverseOrder`|`bool`|Whether the offset starts from the end and the data is returned in reverse.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32[]`|An array of attestation UUIDs.|


### getReceivedAttestationUUIDsCount

*Returns the number of received attestation UUIDs.*


```solidity
function getReceivedAttestationUUIDsCount(address recipient, bytes32 schema) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The recipient of the attestation.|
|`schema`|`bytes32`|The UUID of the AS.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The number of attestations.|


### getSentAttestationUUIDs

*Returns all sent attestation UUIDs.*


```solidity
function getSentAttestationUUIDs(address attester, bytes32 schema, uint256 start, uint256 length, bool reverseOrder)
    external
    view
    returns (bytes32[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`attester`|`address`|The attesting account.|
|`schema`|`bytes32`|The UUID of the AS.|
|`start`|`uint256`|The offset to start from.|
|`length`|`uint256`|The number of total members to retrieve.|
|`reverseOrder`|`bool`|Whether the offset starts from the end and the data is returned in reverse.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32[]`|An array of attestation UUIDs.|


### getSentAttestationUUIDsCount

*Returns the number of sent attestation UUIDs.*


```solidity
function getSentAttestationUUIDsCount(address recipient, bytes32 schema) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The recipient of the attestation.|
|`schema`|`bytes32`|The UUID of the AS.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The number of attestations.|


### getRelatedAttestationUUIDs

*Returns all attestations related to a specific attestation.*


```solidity
function getRelatedAttestationUUIDs(bytes32 uuid, uint256 start, uint256 length, bool reverseOrder)
    external
    view
    returns (bytes32[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`uuid`|`bytes32`|The UUID of the attestation to retrieve.|
|`start`|`uint256`|The offset to start from.|
|`length`|`uint256`|The number of total members to retrieve.|
|`reverseOrder`|`bool`|Whether the offset starts from the end and the data is returned in reverse.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32[]`|An array of attestation UUIDs.|


### getRelatedAttestationUUIDsCount

*Returns the number of related attestation UUIDs.*


```solidity
function getRelatedAttestationUUIDsCount(bytes32 uuid) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`uuid`|`bytes32`|The UUID of the attestation to retrieve.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The number of related attestations.|


### getSchemaAttestationUUIDs

*Returns all per-schema attestation UUIDs.*


```solidity
function getSchemaAttestationUUIDs(bytes32 schema, uint256 start, uint256 length, bool reverseOrder)
    external
    view
    returns (bytes32[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`schema`|`bytes32`|The UUID of the AS.|
|`start`|`uint256`|The offset to start from.|
|`length`|`uint256`|The number of total members to retrieve.|
|`reverseOrder`|`bool`|Whether the offset starts from the end and the data is returned in reverse.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32[]`|An array of attestation UUIDs.|


### getSchemaAttestationUUIDsCount

*Returns the number of per-schema  attestation UUIDs.*


```solidity
function getSchemaAttestationUUIDsCount(bytes32 schema) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`schema`|`bytes32`|The UUID of the AS.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The number of attestations.|


## Events
### Attested
*Triggered when an attestation has been made.*


```solidity
event Attested(address indexed recipient, address indexed attester, bytes32 uuid, bytes32 indexed schema);
```

### Revoked
*Triggered when an attestation has been revoked.*


```solidity
event Revoked(address indexed recipient, address indexed attester, bytes32 uuid, bytes32 indexed schema);
```

## Structs
### Attestation
*A struct representing a single attestation.*


```solidity
struct Attestation {
    bytes32 uuid;
    bytes32 schema;
    address recipient;
    address attester;
    uint256 time;
    uint256 expirationTime;
    uint256 revocationTime;
    bytes32 refUUID;
    bytes data;
}
```

