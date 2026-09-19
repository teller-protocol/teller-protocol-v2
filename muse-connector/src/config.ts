export interface Config {
  port: number
  /** Unset => the fixture backend is used and nothing leaves the process. */
  prequalApiBaseUrl: string | undefined
  prequalApiKey: string | undefined
  usFunnelBaseUrl: string
  supportedCountries: string[]
}

function required(name: string, fallback: string): string {
  const v = process.env[name]?.trim()
  return v && v.length > 0 ? v : fallback
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const base = env.PREQUAL_API_BASE_URL?.trim()
  return {
    port: Number(env.PORT ?? 8080),
    prequalApiBaseUrl: base && base.length > 0 ? base.replace(/\/+$/, '') : undefined,
    prequalApiKey: env.PREQUAL_API_KEY?.trim() || undefined,
    usFunnelBaseUrl: required('US_FUNNEL_BASE_URL', 'https://teller.org/prequalify'),
    supportedCountries: required('SUPPORTED_COUNTRIES', 'US,CA')
      .split(',')
      .map((c) => c.trim().toUpperCase())
      .filter(Boolean),
  }
}
