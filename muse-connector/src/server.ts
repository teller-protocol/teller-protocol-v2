import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { registerTools, type ToolDeps } from './tools/index.js'

export const SERVER_NAME = 'teller-prequal'
export const SERVER_VERSION = '0.1.0'

export function buildServer(deps: ToolDeps): McpServer {
  const server = new McpServer(
    { name: SERVER_NAME, version: SERVER_VERSION },
    {
      instructions:
        'Teller pre-qualification. Helps a borrower find lenders for personal, business, home and auto ' +
        'credit.\n\n' +
        'Order of operations: get_prequal_schema -> check_prequal_route (as soon as you know the country) -> ' +
        'preview_prequal_matches -> get_prequal_disclosure -> submit_prequal.\n\n' +
        'Rules you must follow:\n' +
        '- Preview before submitting. A preview stores nothing; a submission cannot be recalled.\n' +
        '- Never submit off the back of a preview. Get an explicit yes from the borrower first.\n' +
        '- Show the disclosure text verbatim. Do not summarise or rewrite it.\n' +
        '- Never ask for a Social Security number, full date of birth, driver licence number, or bank ' +
        'routing/account numbers. This server refuses them. US borrowers finish on Teller\'s own form.\n' +
        '- A pre-qualification is not an offer of credit and not a guarantee of approval. Do not describe ' +
        'estimated rates as offers.',
    },
  )
  registerTools(server, deps)
  return server
}
