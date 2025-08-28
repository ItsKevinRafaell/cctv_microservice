import Link from 'next/link'
import { Skeleton } from '@/components/ui/skeleton'
import { apiBaseUrl, authHeaderFromCookie, decodeJwt, getToken, uploadBaseUrl } from '@/lib/auth'

async function fetchHealth(path: string) {
  try {
    const res = await fetch(`${apiBaseUrl()}${path}`, { headers: authHeaderFromCookie(), cache: 'no-store' })
    return { ok: res.ok, status: res.status }
  } catch {
    return { ok: false, status: 0 }
  }
}

export default async function Home() {
  async function fetchUploadHealth(path: string) {
    try {
      const res = await fetch(`${uploadBaseUrl()}${path}`, { headers: authHeaderFromCookie(), cache: 'no-store' })
      return { ok: res.ok, status: res.status }
    } catch {
      return { ok: false, status: 0 }
    }
  }
  const [main, ingestion] = await Promise.all([
    fetchHealth('/healthz').catch(() => ({ ok: false, status: 0 })),
    fetchUploadHealth('/healthz').catch(() => ({ ok: false, status: 0 })),
  ])

  const token = getToken()
  const me = decodeJwt(token)

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">System Status</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="border rounded p-4">
          <div className="font-medium">Main Backend</div>
          <div className={main.ok ? 'text-green-600' : 'text-red-600'}>
            {main.ok ? 'Healthy' : 'Unavailable'} ({main.status})
          </div>
        </div>
        <div className="border rounded p-4">
          <div className="font-medium">Ingestion Service</div>
          <div className={ingestion.ok ? 'text-green-600' : 'text-red-600'}>
            {ingestion.ok ? 'Healthy' : 'Unavailable'} ({ingestion.status})
          </div>
        </div>
      </div>

      <div className="border rounded p-4">
        <div className="font-medium mb-2">Quick Links</div>
        <div className="flex flex-wrap gap-2 text-sm">
          <Link href="/companies" className="px-2 py-1 border rounded hover:bg-gray-50">Companies</Link>
          <Link href="/users" className="px-2 py-1 border rounded hover:bg-gray-50">Users</Link>
          <Link href="/cameras" className="px-2 py-1 border rounded hover:bg-gray-50">Cameras</Link>
          <Link href="/anomalies" className="px-2 py-1 border rounded hover:bg-gray-50">Anomalies</Link>
          <Link href="/ingest" className="px-2 py-1 border rounded hover:bg-gray-50">Ingest</Link>
        </div>
      </div>

      <div className="border rounded p-4">
        <div className="font-medium mb-2">Current User</div>
        {!me ? (
          <Skeleton className="h-6 w-64" />
        ) : (
          <div className="text-sm">
            <div>Email: {me.email || me.sub}</div>
            <div>Role: {me.role}</div>
          </div>
        )}
      </div>
    </div>
  )
}
