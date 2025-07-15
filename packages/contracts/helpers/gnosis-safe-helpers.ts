

/*


	how to propose a tx  to gnosis safe 

	curl -X 'POST' \
'https://api.safe.global/tx-service/sep/api/v1/safes/0xc62C5cbB964ffffffffff82f78A4d30713174b2E/multisig-transactions/' \
-H 'accept: application/json' \
-H 'Content-Type: application/json' \
-H 'Authorization: Bearer YOUR_API_KEY' \
-d '{
    "safe": "0xc62C5cbB964459F3C984682f78A4d3ffffffffff",
    "to": "0x795D6C88B4Ea3CCffffffffffCa8a11Bc0496228",
    "value": 2000000000000000,
    "data": null,
    "operation": 0,
    "gasToken": "0x0000000000000000000000000000000000000000",
    "safeTxGas": 0,
    "baseGas": 0,
    "gasPrice": 0,
    "refundReceiver": "0x0000000000000000000000000000000000000000",
    "nonce": 15,
    "contractTransactionHash": "0x56b2931d1053b6afffffffffff3ba29b5c2baafdf1a588850da72a62674941b6",
    "sender": "0xAA86E576c084aCFa56fc4D0E17967ffffffffff8",
    "signature": "0x6a2b57023af16241511619ea95f7cd03d00aa6b79d1ca80e21a0b89cd2c38ffffffffff9b738ffbd680c4d717b9b0c9eae568f3edebc40a0c004700bffffffffff"
}'





*/