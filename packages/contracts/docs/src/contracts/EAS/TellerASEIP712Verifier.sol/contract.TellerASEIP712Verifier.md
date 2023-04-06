# TellerASEIP712Verifier
[Git Source](https://github.com/teller-protocol/teller-protocol-v2/blob/cc7fb9358a2518de7ee33e518ebac21eac498b0d/contracts/EAS/TellerASEIP712Verifier.sol)

**Inherits:**
[IEASEIP712Verifier](/contracts/interfaces/IEASEIP712Verifier.sol/interface.IEASEIP712Verifier.md)


## State Variables
### VERSION

```solidity
string public constant VERSION = "0.8";
```


### DOMAIN_SEPARATOR

```solidity
bytes32 public immutable DOMAIN_SEPARATOR;
```


### ATTEST_TYPEHASH

```solidity
bytes32 public constant ATTEST_TYPEHASH = 0x39c0608dd995a3a25bfecb0fffe6801a81bae611d94438af988caa522d9d1476;
```


### REVOKE_TYPEHASH

```solidity
bytes32 public constant REVOKE_TYPEHASH = 0xbae0931f3a99efd1b97c2f5b6b6e79d16418246b5055d64757e16de5ad11a8ab;
```


### _nonces

```solidity
mapping(address => uint256) private _nonces;
```


## Functions
### constructor

*Creates a new EIP712Verifier instance.*


```solidity
constructor();
```

### getNonce

*Returns the current nonce per-account.*


```solidity
function getNonce(address account) external view override returns (uint256);
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
) external override;
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
function revoke(bytes32 uuid, address attester, uint8 v, bytes32 r, bytes32 s) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`uuid`|`bytes32`|The UUID of the attestation to revoke.|
|`attester`|`address`|The attesting account.|
|`v`|`uint8`|The recovery ID.|
|`r`|`bytes32`|The x-coordinate of the nonce R.|
|`s`|`bytes32`|The signature data.|


## Errors
### InvalidSignature

```solidity
error InvalidSignature();
```

