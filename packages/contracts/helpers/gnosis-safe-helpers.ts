import { ProposalResponse } from '@openzeppelin/defender-admin-client/lib'
import { PartialContract, ProposalStep } from '@openzeppelin/defender-admin-client/lib/models/proposal'
import { Network } from '@openzeppelin/defender-base-client'
import { generateLedgerSignature } from './ledger-nano-helper'

import {Safe} from '@safe-global/protocol-kit' 
 
    
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


interface CreateProposalRequest {
  contract: PartialContract | PartialContract[]
  title: string
  description: string
  type: 'custom' | 'batch'
  viaType: 'Gnosis Safe'
  via: string
  functionInterface?: any
  functionInputs?: any[]
  metadata?: any
  steps?: ProposalStep[]
  nonceOffset?: number
}

interface SafeTransactionRequest {
  safe: string
  to: string
  value: string
  data: string
  operation: number
  gasToken: string
  safeTxGas: number
  baseGas: number
  gasPrice: number
  refundReceiver: string
  nonce: number
  contractTransactionHash: string
  sender: string
  signature: string
}

export class GnosisSafeAdminClient {
  private apiKey: string
  private baseUrl: string = 'https://api.safe.global'

  constructor(config: { apiKey: string }) {
    if (!config.apiKey) {
      throw new Error('SAFE_GLOBAL_API_KEY is required. Get your API key at: https://app.safe.global/settings/setup')
    }
    this.apiKey = config.apiKey
  }

  async createProposal(request: CreateProposalRequest): Promise<ProposalResponse> {
    const safeAddress = request.via

    var network = request.contract.network;

    //hack ..
    if (network == 'matic') {
      network = 'polygon'
    }

    console.log( `network: ${network }`  )

    if (request.type === 'batch') {
      return await this.createBatchProposal(request, safeAddress, network)
    } else {
      return await this.createSingleProposal(request, safeAddress, network)
    }
  }

  private async createSingleProposal(
    request: CreateProposalRequest,
    safeAddress: string,
    network: string
  ): Promise<ProposalResponse> {
    const contract = Array.isArray(request.contract) ? request.contract[0] : request.contract
    const contractAddress = contract.address
    
    const encodedData = this.encodeTransactionData(
      request.functionInterface,
      request.functionInputs
    )

    const nonce = await this.getNextNonce(safeAddress, network, request.nonceOffset || 0)
      
    console.log({nonce});

    // Generate transaction hash first
    const txHash = await this.generateTransactionHash(
      safeAddress,
      contractAddress,
      encodedData,
      '0',
      0,
      0,
      0,
      0,
      '0x0000000000000000000000000000000000000000',
      '0x0000000000000000000000000000000000000000',
      nonce,
      network
    )
    
    const ledgerSignatureResult = await generateLedgerSignature({
      to: contractAddress,
      data: encodedData,
      value: '0',
      safeAddress,
      nonce,
      txHash
    })

    const transactionRequest: SafeTransactionRequest = {
      safe: safeAddress,
      to: contractAddress,
      value: '0',
      data: encodedData,
      operation: 0,
      gasToken: '0x0000000000000000000000000000000000000000',
      safeTxGas: 0,
      baseGas: 0,
      gasPrice: 0,
      refundReceiver: '0x0000000000000000000000000000000000000000',
      nonce,
      contractTransactionHash: txHash,
      sender: ledgerSignatureResult.signerAddress,
      signature: ledgerSignatureResult.signature
    }
    console.log( ledgerSignatureResult )

    console.log( transactionRequest )

    const response = await this.submitTransaction(transactionRequest, network)
    
    return {
      proposalId: response.safeTxHash || 'unknown',
      url: `${this.baseUrl}/app/transactions/queue?safe=${safeAddress}`,
      transaction: {
        hash: response.safeTxHash
      }
    }
  }

  private async createBatchProposal(
    request: CreateProposalRequest,
    safeAddress: string,
    network: string
  ): Promise<ProposalResponse> {
    if (!request.steps) {
      throw new Error('Batch proposal requires steps')
    }

    const transactions = request.steps.map(step => {
      const contract = Array.isArray(request.contract) 
        ? request.contract.find(c => c.address === step.contractId?.split('-')[1])
        : request.contract

      if (!contract) {
        throw new Error(`Contract not found for step ${step.contractId}`)
      }

      const encodedData = this.encodeTransactionData(
        step.targetFunction,
        step.functionInputs
      )

      return {
        to: contract.address,
        value: '0',
        data: encodedData,
        operation: 0
      }
    })

    const multiSendData = this.encodeMultiSendData(transactions)
    const multiSendAddress = this.getMultiSendAddress(network)

    const nonce = await this.getNextNonce(safeAddress, network, request.nonceOffset || 0)

      console.log({nonce});
      
    const ledgerSignatureResult = await generateLedgerSignature({
      to: multiSendAddress,
      data: multiSendData,
      value: '0',
      safeAddress,
      nonce
    })

    const transactionRequest: SafeTransactionRequest = {
      safe: safeAddress,
      to: multiSendAddress,
      value: '0',
      data: multiSendData,
      operation: 1,
      gasToken: '0x0000000000000000000000000000000000000000',
      safeTxGas: 0,
      baseGas: 0,
      gasPrice: 0,
      refundReceiver: '0x0000000000000000000000000000000000000000',
      nonce,
      contractTransactionHash: await this.generateTransactionHash(
        safeAddress,
        multiSendAddress,
        multiSendData,
        '0',
        1,
        0,
        0,
        0,
        '0x0000000000000000000000000000000000000000',
        '0x0000000000000000000000000000000000000000',
        nonce,
        network
      ),
      sender: ledgerSignatureResult.signerAddress,
      signature: ledgerSignatureResult.signature
    }

    const response = await this.submitTransaction(transactionRequest, network)
    
    return {
      proposalId: response.safeTxHash || 'unknown',
      url: `${this.baseUrl}/app/transactions/queue?safe=${safeAddress}`,
      transaction: {
        hash: response.safeTxHash
      }
    }
  }

  private async submitTransaction(
    transaction: SafeTransactionRequest,
    network: string
  ): Promise<{ safeTxHash: string }> {
    const txServiceHost = this.getTxServiceHost(network)
    // Safe Global moved to network-specific subdomains
    const url = `${txServiceHost}/api/v1/safes/${transaction.safe}/multisig-transactions/`
      

      console.log(`submitTransaction ${url }`)
      console.log('Transaction payload:', JSON.stringify(transaction, null, 2))


    const headers: Record<string, string> = {
      'accept': 'application/json',
      'content-type': 'application/json',
      'Authorization': `Bearer ${this.apiKey}`
    }

    console.log('Request headers:', headers)
    
    const response = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify(transaction)
    })
    
    console.log('Response status:', response.status)
    console.log('Response headers:', Object.fromEntries(response.headers.entries()))

    if (!response.ok) {
      const error = await response.text()
      throw new Error(`Failed to submit transaction to Safe: ${response.status} ${error}`)
    }

    const responseText = await response.text()
    console.log('Safe API response:', responseText)
    
    // Safe API returns 201 with empty body on successful submission
    if (response.status === 201 && !responseText) {
      console.log('Transaction successfully submitted to Safe (201 with empty response)')
      return { success: true, safeTxHash: transaction.contractTransactionHash }
    }
    
    if (!responseText) {
      throw new Error('Empty response from Safe API')
    }
    
    try {
      return JSON.parse(responseText)
    } catch (parseError) {
      throw new Error(`Failed to parse Safe API response: ${parseError.message}. Response: ${responseText}`)
    }
  }

  private encodeTransactionData(functionInterface: any, functionInputs: any[]): string {
    if (!functionInterface || !functionInputs) {
      return '0x'
    }

    const { ethers } = require('ethers')
    
    const types = functionInterface.inputs.map((input: any) => input.type)
    const fragment = ethers.FunctionFragment.from({
      name: functionInterface.name,
      type: 'function',
      inputs: functionInterface.inputs
    })
    
    const iface = new ethers.Interface([fragment])
    return iface.encodeFunctionData(functionInterface.name, functionInputs)
  }

  private encodeMultiSendData(transactions: Array<{to: string, value: string, data: string, operation: number}>): string {
    const { ethers } = require('ethers')
    
    let data = '0x'
    for (const tx of transactions) {
      const encoded = ethers.solidityPacked(
        ['uint8', 'address', 'uint256', 'uint256', 'bytes'],
        [tx.operation, tx.to, tx.value, ethers.dataLength(tx.data), tx.data]
      )
      data += encoded.slice(2)
    }
    
    const multiSendInterface = new ethers.Interface([
      'function multiSend(bytes transactions)'
    ])
    
    return multiSendInterface.encodeFunctionData('multiSend', [data])
  }

  /*
  Fetches the next nonce for a Safe using the new Safe API format with authentication.

  Example endpoint:
  https://api.safe.global/tx-service/eth/api/v2/safes/0xcd2E72aEBe2A203b84f46DEEC948E6465dB51c75/

  Requires API key authentication (get from https://app.safe.global/settings/setup)
  */
  private async getNextNonce(safeAddress: string, network: string, offset: number = 0): Promise<number> {
   
      //force a particular nonce 
      return 75 + offset; 


    const txServiceHost = this.getTxServiceHost(network)
    // Safe Global moved to network-specific subdomains
    const url = `${txServiceHost}/api/v1/safes/${safeAddress}/`

    console.log(`getNextNonce ${url}`)

    const headers: Record<string, string> = {
      'accept': 'application/json',
      'content-type': 'application/json'
    }

    const response = await fetch(url, {
      headers
    })

    
    if (!response.ok) {
      const errorText = await response.text()
      if (response.status === 404) {
       // console.warn(`Safe not found, using nonce 0. This might be a new Safe or incorrect network.`)
       // return 0
      }



      //try to get getNextNonceV1 and return that ..  ? 
       


      // return 71 + offset  // hack for now    use this if needed x.x 

      throw new Error(`Failed to get Safe info: ${response.status} - ${errorText}`)
    }

    const safeInfo = await response.json()
    return parseInt(safeInfo.nonce) + parseInt(offset)
  }


  /*private async getNextNonceV1(safeAddress: string, network: string, offset: number = 0): Promise<number> {
      
      // https://api.safe.global/tx-service/eth/api/v1/safes/0x9E3bfee4C6b4D28b5113E4786A1D9812eB3D2Db6/ 

      // this works , oddly enough 


    const chainName = this.getNetworkPath([{network} as any])
     let backup_url = `https://api.safe.global/tx-service/${chainName}/api/v1/safes/${safeAddress}/`;
    
      console.log(`getNextNonce ${url}`)

    const headers: Record<string, string> = {
      'accept': 'application/json',
      'content-type': 'application/json' 
       
    }

    const response = await fetch(backup_url, {
      headers
    })

    
    if (!response.ok) {
      const errorText = await response.text()
      if (response.status === 404) {
       // console.warn(`Safe not found, using nonce 0. This might be a new Safe or incorrect network.`)
       // return 0
      } 

      // return 71 + offset  // hack for now    use this if needed x.x 

      throw new Error(`Failed to get Safe info: ${response.status} - ${errorText}`)
    }

    const safeInfo = await response.json()
    return parseInt(safeInfo.nonce) + parseInt(offset)
  }*/



  private getChainId(network: string): number {
    const chainIds: Record<string, number> = {
      'mainnet': 1,
      'sepolia': 11155111,
      'goerli': 5,
      'polygon': 137,
      'arbitrum': 42161,
      'optimism': 10,
      'base': 8453,
      'gnosis': 100,
      'avalanche': 43114,
      'bsc': 56,
      'katana':747474
    }
    return chainIds[network] || 1
  }

  private async generateTransactionHash(
    safeAddress: string,
    to: string,
    data: string,
    value: string,
    operation: number,
    safeTxGas: number,
    baseGas: number,
    gasPrice: number,
    gasToken: string,
    refundReceiver: string,
    nonce: number,
    network: string
  ): Promise<string> {
    const { ethers } = require('ethers')
    
    // Gnosis Safe transaction hash format using EIP-712
    const domain = {
      chainId: this.getChainId(network),
      verifyingContract: safeAddress
    }
    
    const types = {
      SafeTx: [
        { type: 'address', name: 'to' },
        { type: 'uint256', name: 'value' },
        { type: 'bytes', name: 'data' },
        { type: 'uint8', name: 'operation' },
        { type: 'uint256', name: 'safeTxGas' },
        { type: 'uint256', name: 'baseGas' },
        { type: 'uint256', name: 'gasPrice' },
        { type: 'address', name: 'gasToken' },
        { type: 'address', name: 'refundReceiver' },
        { type: 'uint256', name: 'nonce' }
      ]
    }
    
    const message = {
      to,
      value,
      data,
      operation,
      safeTxGas,
      baseGas,
      gasPrice,
      gasToken,
      refundReceiver,
      nonce
    }
    
    const safeTxHash = ethers.TypedDataEncoder.hash(domain, types, message)
    console.log(`tx hash is ${safeTxHash}`);
    return safeTxHash
  }

  private getNetworkPath(contract: PartialContract | PartialContract[]): string {
    const firstContract = Array.isArray(contract) ? contract[0] : contract
    const network = firstContract.network

    // Maps Hardhat network names to Safe API EIP3770 chain names
    // Format: https://api.safe.global/tx-service/{chain}/api/v2/...
    const networkMap: Record<string, string> = {
      'mainnet': 'eth',
      'sepolia': 'sep',
      'goerli': 'gor',
      'polygon': 'matic',
      'arbitrum': 'arb1',
      'optimism': 'oeth',
      'base': 'base',
      'gnosis': 'gno',
      'avalanche': 'avax',
      'bsc': 'bnb',
      'katana': 'katana',
    }

    return networkMap[network as string] || 'eth'
  }

  // Returns the Safe Transaction Service host URL for the given network
  // Safe Global now uses network-specific subdomains: https://safe-transaction-{network}.safe.global
  private getTxServiceHost(network: string): string {
    const networkMap: Record<string, string> = {
      'mainnet': 'https://safe-transaction-mainnet.safe.global',
      'sepolia': 'https://safe-transaction-sepolia.safe.global',
      'goerli': 'https://safe-transaction-goerli.safe.global',
      'polygon': 'https://safe-transaction-polygon.safe.global',
      'arbitrum': 'https://safe-transaction-arbitrum.safe.global',
      'optimism': 'https://safe-transaction-optimism.safe.global',
      'base': 'https://safe-transaction-base.safe.global',
      'gnosis': 'https://safe-transaction-gnosis-chain.safe.global',
      'avalanche': 'https://safe-transaction-avalanche.safe.global',
      'bsc': 'https://safe-transaction-bsc.safe.global',
    }
    return networkMap[network] || 'https://safe-transaction-mainnet.safe.global'
  }

/*
The MultiSend contract address 0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761 is the canonical MultiSend contract deployed on most
  networks by Gnosis Safe. This is a well-known, audited contract that:

  - Takes an encoded bytes array containing multiple transaction data
  - Executes each transaction in sequence
  - Ensures all transactions succeed or the entire batch fails (atomic execution)

  
  In the code at /home/andy/teller/teller-protocol-v2/packages/contracts/helpers/gnosis-safe-helpers.ts:266-268, the
  getMultiSendAddress() method returns this standard address. For batch proposals, the operation field is set to 1 (DELEGATECALL)
  instead of 0 (CALL), which tells the Safe to delegate the execution to the MultiSend contract.


*/
  private getMultiSendAddress(network: string): string {
    return '0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761'
  }
}