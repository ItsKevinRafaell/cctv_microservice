import { NextRequest, NextResponse } from 'next/server'
import { uploadBaseUrl, getToken } from '@/lib/auth'

function buildUrl(base: string, path: string, search: string) {
  const slash = path.startsWith('/') ? '' : '/'
  return `${base}${slash}${path}${search ? `?${search}` : ''}`
}

async function handle(req: NextRequest, { params }: { params: { path: string[] } }) {
  const path = (params.path || []).join('/')
  const url = buildUrl(uploadBaseUrl(), path, req.nextUrl.searchParams.toString())
  const token = getToken()

  const headers = new Headers(req.headers)
  headers.set('host', new URL(uploadBaseUrl()).host)
  if (token) headers.set('authorization', `Bearer ${token}`)

  const init: RequestInit = {
    method: req.method,
    headers,
    body: ['GET', 'HEAD'].includes(req.method) ? undefined : await req.arrayBuffer(),
    redirect: 'manual',
  }

  const upstream = await fetch(url, init)

  const respHeaders = new Headers(upstream.headers)
  respHeaders.delete('content-encoding')
  respHeaders.delete('transfer-encoding')

  const body = await upstream.arrayBuffer()
  return new NextResponse(body, { status: upstream.status, headers: respHeaders })
}

export const GET = handle
export const POST = handle
export const PUT = handle
export const PATCH = handle
export const DELETE = handle

