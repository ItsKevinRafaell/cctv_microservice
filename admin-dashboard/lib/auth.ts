import { cookies, headers } from 'next/headers'

export const TOKEN_COOKIE = 'token'

export type JwtPayload = {
  sub?: string
  email?: string
  role?: 'superadmin' | 'company_admin' | 'user'
  exp?: number
  [k: string]: unknown
}

export function getToken(): string | undefined {
  // server-side cookies
  const c = cookies()
  return c.get(TOKEN_COOKIE)?.value
}

export function decodeJwt(token: string | undefined): JwtPayload | undefined {
  if (!token) return undefined
  try {
    const [, payloadB64] = token.split('.')
    if (!payloadB64) return undefined
    const json = Buffer.from(payloadB64, 'base64').toString('utf8')
    return JSON.parse(json)
  } catch {
    return undefined
  }
}

export function authHeaderFromCookie(): HeadersInit {
  const token = getToken()
  return token ? { Authorization: `Bearer ${token}` } : {}
}

export function apiBaseUrl(): string {
  return process.env.API_BASE_URL || 'http://localhost:8080'
}

