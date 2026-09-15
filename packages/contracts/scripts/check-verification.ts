/**
 * Ground truth on what is actually verified on the explorer.
 *
 * hardhat-verify 1.x predates Etherscan V2 and drops the `chainid` query
 * param when it polls for a verification result, so it reports
 *
 *   Failed to verify ... Reason: Missing chainid parameter
 *   The verification may still succeed but should be checked manually.
 *
 * on submissions the API accepted. This is that manual check: ask the V2 API
 * directly, for every address in deployments/<network>/, and print what it
 * says. Exits non-zero if anything is unverified, so a run can gate on it.
 */
import fs from 'fs'
import path from 'path'

import hre from 'hardhat'

const API = 'https://api.etherscan.io/v2/api'

interface Row {
  name: string
  address: string
  status: string
}

async function isVerified(
  chainId: number,
  address: string,
  apiKey: string
): Promise<string> {
  const url = `${API}?chainid=${chainId}&module=contract&action=getsourcecode&address=${address}&apikey=${apiKey}`
  const res = await fetch(url)
  if (!res.ok) return `http ${res.status}`
  const body = (await res.json()) as {
    status: string
    result?: Array<{ SourceCode?: string; ContractName?: string }>
  }
  if (body.status !== '1') return 'api error'
  const entry = body.result?.[0]
  if (!entry) return 'no result'
  return entry.SourceCode ? `verified (${entry.ContractName})` : 'UNVERIFIED'
}

async function main(): Promise<void> {
  const network = hre.network.name
  const chainId = hre.network.config.chainId
  if (chainId === undefined) throw new Error(`No chainId for ${network}`)

  const apiKey =
    process.env[`${network.toUpperCase().replace(/-/g, '_')}_VERIFY_API_KEY`] ??
    process.env.ETHERSCANV2_VERIFY_API_KEY
  if (!apiKey) throw new Error('No verification API key in the environment.')

  const dir = path.join('deployments', network)
  const rows: Row[] = []
  for (const file of fs.readdirSync(dir).sort()) {
    if (!file.endsWith('.json')) continue
    const { address } = JSON.parse(
      fs.readFileSync(path.join(dir, file), 'utf8')
    ) as { address?: string }
    if (!address) continue
    const name = file.replace(/\.json$/, '')
    rows.push({ name, address, status: await isVerified(chainId, address, apiKey) })
    // Etherscan rate-limits free keys to ~5 calls/sec.
    await new Promise((r) => setTimeout(r, 250))
  }

  const width = Math.max(...rows.map((r) => r.name.length))
  for (const r of rows) {
    console.log(`${r.name.padEnd(width)}  ${r.address}  ${r.status}`)
  }

  const bad = rows.filter((r) => !r.status.startsWith('verified'))
  console.log(`\n${rows.length - bad.length}/${rows.length} verified`)
  if (bad.length > 0) {
    throw new Error(`${bad.length} contract(s) not verified on chain ${chainId}`)
  }
}

main().catch((err: unknown) => {
  console.error(err instanceof Error ? err.message : err)
  process.exit(1)
})
