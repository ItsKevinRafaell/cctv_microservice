import { NextRequest, NextResponse } from 'next/server'

export async function POST(req: NextRequest) {
  const res = NextResponse.redirect(new URL('/login', req.url))
  res.cookies.set('token', '', { httpOnly: true, path: '/', maxAge: 0 })
  return res
}
