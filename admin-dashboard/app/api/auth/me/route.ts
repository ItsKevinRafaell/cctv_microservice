import { NextResponse } from 'next/server'
import { decodeJwt, getToken } from '@/lib/auth'

export async function GET() {
  const token = getToken()
  const me = decodeJwt(token)
  if (!me) return new NextResponse('Unauthorized', { status: 401 })
  return NextResponse.json({
    email: me.email || me.sub,
    role: me.role,
    company_id: (me as any).company_id,
  })
}

