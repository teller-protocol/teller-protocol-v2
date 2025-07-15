import { ethers } from 'ethers'

interface LedgerSignatureRequest {
  to: string
  data: string
  value?: string
  safeAddress: string
  nonce: number
}

export async function generateLedgerSignature(request: LedgerSignatureRequest): Promise<string> {
  try {
    const TransportNodeHid = require('@ledgerhq/hw-transport-node-hid').default
    const AppEth = require('@ledgerhq/hw-app-eth').default

    const transport = await TransportNodeHid.create()
    const eth = new AppEth(transport)

    const txHash = ethers.keccak256(
      ethers.solidityPacked(
        ['address', 'address', 'uint256', 'bytes', 'uint256'],
        [request.safeAddress, request.to, request.value || '0', request.data, request.nonce]
      )
    )

    //change me to the correct one for YOU 
    let ledger_account_id = 10;

    const signature = await eth.signPersonalMessage(
      "44'/60'/0'/0/".concat(ledger_account_id.toString()),
      txHash.slice(2)
    )

    await transport.close()

    const v = signature.v
    const r = '0x' + signature.r
    const s = '0x' + signature.s

    return ethers.solidityPacked(['uint8', 'bytes32', 'bytes32'], [v, r, s])
  } catch (error) {
    console.error('Failed to generate Ledger signature:', error)
    throw new Error(`Ledger signature generation failed: ${error.message}`)
  }
}

/*

 const message =
          "Sign this message to prove you have access to this wallet in order to sign in to thegraph.com/studio.\n\n" +
          "This won't cost you any Ether.\n\n" +
          `Timestamp: ${Date.now()}`;

        const sig = await eth.signPersonalMessage(
          foundPath,
          Buffer.from(message).toString("hex")
        );
        const signature = `0x${sig.r}${sig.s}${sig.v.toString(16)}`;

        await transport.close();


*/