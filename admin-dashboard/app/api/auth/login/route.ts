import { NextRequest, NextResponse } from 'next/server'
import { apiBaseUrl } from '@/lib/auth'

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}))
  const res = await fetch(`${apiBaseUrl()}/api/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })

  if (!res.ok) {
    return new NextResponse(await res.text(), { status: res.status })
  }

  const data = await res.json().catch(() => ({} as any))
  const token = data?.token || data?.access_token
  if (!token) {
    return new NextResponse('Invalid login response', { status: 502 })
  }

  const response = NextResponse.json({ ok: true })
  response.cookies.set('token', token, {
    httpOnly: true,
    sameSite: 'lax',
    secure: false,
    path: '/',
  })
  return response
}

