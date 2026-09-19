import { createServer, type IncomingMessage, type ServerResponse } from 'node:http'
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js'
import { loadConfig } from './config.js'
import { InMemoryAckStore } from './disclosure.js'
import { buildServer, SERVER_NAME, SERVER_VERSION } from './server.js'
import { createPrequalClient } from './upstream/client.js'

const config = loadConfig()
const { client, mode } = createPrequalClient(config)
const ackStore = new InMemoryAckStore()

const MAX_BODY_BYTES = 1024 * 1024

function readBody(req: IncomingMessage): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = []
    let size = 0
    req.on('data', (chunk: Buffer) => {
      size += chunk.length
      if (size > MAX_BODY_BYTES) {
        reject(new Error('Request body too large'))
        req.destroy()
        return
      }
      chunks.push(chunk)
    })
    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf8')
      if (!raw) return resolve(undefined)
      try {
        resolve(JSON.parse(raw))
      } catch {
        reject(new Error('Request body is not valid JSON'))
      }
    })
    req.on('error', reject)
  })
}

function json(res: ServerResponse, status: number, payload: unknown): void {
  const body = JSON.stringify(payload)
  res.writeHead(status, { 'content-type': 'application/json', 'content-length': Buffer.byteLength(body) })
  res.end(body)
}

/**
 * Stateless streamable HTTP: a fresh server and transport per request, so the
 * process can be load balanced without sticky sessions. Anything that must
 * outlive a request (consent acknowledgements) lives in the ack store, which a
 * multi-instance deployment must back with Redis rather than memory.
 */
async function handleMcp(req: IncomingMessage, res: ServerResponse): Promise<void> {
  if (req.method !== 'POST') {
    json(res, 405, {
      jsonrpc: '2.0',
      error: { code: -32000, message: 'This server is stateless; use POST.' },
      id: null,
    })
    return
  }

  let body: unknown
  try {
    body = await readBody(req)
  } catch (err) {
    json(res, 400, {
      jsonrpc: '2.0',
      error: { code: -32700, message: err instanceof Error ? err.message : 'Bad request' },
      id: null,
    })
    return
  }

  const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined, enableJsonResponse: true })
  const server = buildServer({ config, client, ackStore, mode })

  res.on('close', () => {
    void transport.close()
    void server.close()
  })

  try {
    await server.connect(transport)
    await transport.handleRequest(req, res, body)
  } catch (err) {
    console.error('[mcp] request failed', err)
    if (!res.headersSent) {
      json(res, 500, { jsonrpc: '2.0', error: { code: -32603, message: 'Internal server error' }, id: null })
    }
  }
}

const httpServer = createServer((req, res) => {
  const url = new URL(req.url ?? '/', `http://${req.headers.host ?? 'localhost'}`)

  if (url.pathname === '/healthz') {
    json(res, 200, { ok: true, server: SERVER_NAME, version: SERVER_VERSION, upstream: mode })
    return
  }
  if (url.pathname === '/mcp') {
    void handleMcp(req, res)
    return
  }
  json(res, 404, { error: 'not_found', hint: 'MCP endpoint is POST /mcp' })
})

httpServer.listen(config.port, () => {
  console.error(`${SERVER_NAME} v${SERVER_VERSION} listening on :${config.port}/mcp (upstream: ${mode})`)
  if (mode === 'fixture') {
    console.error('WARNING: running against the fixture backend. No lead will reach a real lender.')
  }
})
