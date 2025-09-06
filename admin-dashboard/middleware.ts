import { NextRequest, NextResponse } from 'next/server'
import type { Role } from '@/lib/roles'
import { isAllowed } from '@/lib/roles'

function b64UrlToB64(input: string) {
  return input.replace(/-/g, '+').replace(/_/g, '/')
}

function decodeRole(token: string | undefined): Role | undefined {
  if (!token) return undefined
  try {
    const payloadB64 = token.split('.')[1]
    if (!payloadB64) return undefined
    const jsonStr = atob(b64UrlToB64(payloadB64))
    const json = JSON.parse(jsonStr)
    return json.role as Role | undefined
  } catch {
    return undefined
  }
}

const publicRoutes = [
  '/login',
  '/api/auth/login',
  '/favicon.ico',
]

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl
  if (publicRoutes.some((p) => pathname === p || pathname.startsWith('/_next'))) {
    return NextResponse.next()
  }

  const token = req.cookies.get('token')?.value
  if (!token) {
    const url = req.nextUrl.clone()
    url.pathname = '/login'
    return NextResponse.redirect(url)
  }

  const role = decodeRole(token)
  if (!isAllowed(pathname, role)) {
    const url = req.nextUrl.clone()
    url.pathname = '/'
    return NextResponse.redirect(url)
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
}
