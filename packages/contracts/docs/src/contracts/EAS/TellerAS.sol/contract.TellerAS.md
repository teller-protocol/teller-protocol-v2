# TellerAS
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/EAS/TellerAS.sol)

**Inherits:**
[IEAS](/contracts/interfaces/IEAS.sol/interface.IEAS.md)


## State Variables
### VERSION

```solidity
string public constant VERSION = "0.8";
```


### HASH_TERMINATOR

```solidity
string private constant HASH_TERMINATOR = "@";
```


### _asRegistry

```solidity
IASRegistry private immutable _asRegistry;
```


### _eip712Verifier

```solidity
IEASEIP712Verifier private immutable _eip712Verifier;
```


### _relatedAttestations

```solidity
mapping(bytes32 => bytes32[]) private _relatedAttestations;
```


### _receivedAttestations

```solidity
mapping(address => mapping(bytes32 => bytes32[])) private _receivedAttestations;
```


### _sentAttestations

```solidity
mapping(address => mapping(bytes32 => bytes32[])) private _sentAttestations;
```


### _schemaAttestations

```solidity
mapping(bytes32 => bytes32[]) private _schemaAttestations;
```


### _db

```solidity
mapping(bytes32 => Attestation) private _db;
```


### _attestationsCount

```solidity
uint256 private _attestationsCount;
```


### _lastUUID

```solidity
bytes32 private _lastUUID;
```


## Functions
### constructor

*Creates a new EAS instance.*


```solidity
constructor(IASRegistry registry, IEASEIP712Verifier verifier);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry`|`IASRegistry`|The address of the global AS registry.|
|`verifier`|`IEASEIP712Verifier`|The address of the EIP712 verifier.|


### getASRegistry

*Returns the address of the AS global registry.*


```solidity
function getASRegistry() external view override returns (IASRegistry);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IASRegistry`|The address of the AS global registry.|


### getEIP712Verifier

*Returns the address of the EIP712 verifier used to verify signed attestations.*


```solidity
function getEIP712Verifier() external view override returns (IEASEIP712Verifier);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IEASEIP712Verifier`|The address of the EIP712 verifier used to verify signed attestations.|


### getAttestationsCount

*Returns the global counter for the total number of attestations.*


```solidity
function getAttestationsCount() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The global counter for the total number of attestations.|


### attest

*Attests to a specific AS.*


```solidity
function attest(address recipient, bytes32 schema, uint256 expirationTime, bytes32 refUUID, bytes calldata data)
    public
    payable
    virtual
    override
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
) public payable virtual override returns (bytes32);
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
function revoke(bytes32 uuid) public virtual override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`uuid`|`bytes32`|The UUID of the attestation to revoke.|


### revokeByDelegation

*Attests to a specific AS using a provided EIP712 signature.*


```solidity
function revokeByDelegation(bytes32 uuid, address attester, uint8 v, bytes32 r, bytes32 s) public virtual override;
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
function getAttestation(bytes32 uuid) external view override returns (Attestation memory);
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
function isAttestationValid(bytes32 uuid) public view override returns (bool);
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
function isAttestationActive(bytes32 uuid) public view virtual override returns (bool);
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
) external view override returns (bytes32[] memory);
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
function getReceivedAttestationUUIDsCount(address recipient, bytes32 schema) external view override returns (uint256);
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
    override
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
function getSentAttestationUUIDsCount(address recipient, bytes32 schema) external view override returns (uint256);
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
    override
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
function getRelatedAttestationUUIDsCount(bytes32 uuid) external view override returns (uint256);
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
    override
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
function getSchemaAttestationUUIDsCount(bytes32 schema) external view override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`schema`|`bytes32`|The UUID of the AS.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The number of attestations.|


### _attest

*Attests to a specific AS.*


```solidity
function _attest(
    address recipient,
    bytes32 schema,
    uint256 expirationTime,
    bytes32 refUUID,
    bytes calldata data,
    address attester
) private returns (bytes32);
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

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The UUID of the new attestation.|


### getLastUUID


```solidity
function getLastUUID() external view returns (bytes32);
```

### _revoke

*Revokes an existing attestation to a specific AS.*


```solidity
function _revoke(bytes32 uuid, address attester) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`uuid`|`bytes32`|The UUID of the attestation to revoke.|
|`attester`|`address`|The attesting account.|


### _getUUID

*Calculates a UUID for a given attestation.*


```solidity
function _getUUID(Attestation memory attestation) private view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`attestation`|`Attestation`|The input attestation.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Attestation UUID.|


### _sliceUUIDs

*Returns a slice in an array of attestation UUIDs.*


```solidity
function _sliceUUIDs(bytes32[] memory uuids, uint256 start, uint256 length, bool reverseOrder)
    private
    pure
    returns (bytes32[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`uuids`|`bytes32[]`|The array of attestation UUIDs.|
|`start`|`uint256`|The offset to start from.|
|`length`|`uint256`|The number of total members to retrieve.|
|`reverseOrder`|`bool`|Whether the offset starts from the end and the data is returned in reverse.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32[]`|An array of attestation UUIDs.|


## Errors
### AccessDenied

```solidity
error AccessDenied();
```

### AlreadyRevoked

```solidity
error AlreadyRevoked();
```

### InvalidAttestation

```solidity
error InvalidAttestation();
```

### InvalidExpirationTime

```solidity
error InvalidExpirationTime();
```

### InvalidOffset

```solidity
error InvalidOffset();
```

### InvalidRegistry

```solidity
error InvalidRegistry();
```

### InvalidSchema

```solidity
error InvalidSchema();
```

### InvalidVerifier

```solidity
error InvalidVerifier();
```

### NotFound

```solidity
error NotFound();
```

### NotPayable

```solidity
error NotPayable();
```

