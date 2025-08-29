import Link from 'next/link'
import { Skeleton } from '@/components/ui/skeleton'
import { apiBaseUrl, authHeaderFromCookie, decodeJwt, getToken, uploadBaseUrl, pushBaseUrl, mediaBaseUrl } from '@/lib/auth'
import PageHeader from '@/components/page-header'

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
  async function probe(url: string, init?: RequestInit) {
    try {
      const res = await fetch(url, { headers: authHeaderFromCookie(), cache: 'no-store', ...(init||{}) })
      return { ok: res.ok, status: res.status }
    } catch {
      return { ok: false, status: 0 }
    }
  }
  const [main, ingestion] = await Promise.all([
    fetchHealth('/healthz').catch(() => ({ ok: false, status: 0 })),
    fetchUploadHealth('/healthz').catch(() => ({ ok: false, status: 0 })),
  ])

  // Optional services
  const pushUrl = pushBaseUrl()
  const mediaUrl = mediaBaseUrl()
  const [pushSvc, mediaSvc] = await Promise.all([
    (async ()=>{
      if (!pushUrl) return undefined as any
      // push-service has /send endpoint (POST). Probe with OPTIONS to verify liveness; 200/204/405 indicate up.
      const r = await probe(`${pushUrl}/send`, { method: 'OPTIONS' })
      return { ok: r.status > 0, status: r.status }
    })(),
    (async ()=>{
      if (!mediaUrl) return undefined as any
      const r = await probe(mediaUrl)
      return { ok: r.status > 0, status: r.status }
    })(),
  ])

  // Aggregated report from backend (includes DB + S3 + externals)
  let report: any = null
  try {
    const r = await fetch(`${apiBaseUrl()}/api/health/report`, { headers: authHeaderFromCookie(), cache: 'no-store' })
    if (r.ok) report = await r.json()
  } catch {}

  const token = getToken()
  const me = decodeJwt(token)

  return (
    <div className="space-y-6">
      <PageHeader title="Overview" />
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        <div className="card">
          <div className="font-medium">Main Backend</div>
          <div className={main.ok ? 'text-green-600' : 'text-red-600'}>
            {main.ok ? 'Healthy' : 'Unavailable'} ({main.status})
          </div>
        </div>
        <div className="card">
          <div className="font-medium">Ingestion Service</div>
          <div className={ingestion.ok ? 'text-green-600' : 'text-red-600'}>
            {ingestion.ok ? 'Healthy' : 'Unavailable'} ({ingestion.status})
          </div>
        </div>
        {pushUrl && (
          <div className="card">
            <div className="font-medium">Push Service</div>
            <div className={(pushSvc?.ok ? 'text-green-600' : 'text-yellow-600')}>
              {(pushSvc?.ok ? 'Reachable' : 'No response')} ({pushSvc?.status || 0})
            </div>
          </div>
        )}
        {mediaUrl && (
          <div className="card">
            <div className="font-medium">Media Server</div>
            <div className={(mediaSvc?.ok ? 'text-green-600' : 'text-yellow-600')}>
              {(mediaSvc?.ok ? 'Reachable' : 'No response')} ({mediaSvc?.status || 0})
            </div>
          </div>
        )}
      </div>

      <div className="card">
        <div className="font-medium mb-2">Quick Links</div>
        <div className="flex flex-wrap gap-2 text-sm">
          <Link href="/companies" className="btn btn-outline">Companies</Link>
          <Link href="/users" className="btn btn-outline">Users</Link>
          <Link href="/cameras" className="btn btn-outline">Cameras</Link>
          <Link href="/anomalies" className="btn btn-outline">Anomalies</Link>
          <Link href="/ingest" className="btn btn-outline">Ingest</Link>
        </div>
      </div>

      {report && (
        <div className="card">
          <div className="font-medium mb-2">Detailed Health Report</div>
          <div className="grid md:grid-cols-2 xl:grid-cols-3 gap-3 text-sm">
            <div className="border rounded p-3">
              <div className="font-medium mb-1">Database</div>
              <div className={(report.database?.ok ? 'text-green-600':'text-red-600')}>{report.database?.ok ? 'OK' : 'Error'}</div>
            </div>
            <div className="border rounded p-3">
              <div className="font-medium mb-1">Object Storage (S3)</div>
              <div className={(report.s3?.ok ? 'text-green-600':'text-red-600')}>{report.s3?.ok ? 'OK' : 'Error'}</div>
              <div className="text-xs text-gray-600 mt-1">Archive bucket: {String(report.s3?.archive_bucket)}</div>
              <div className="text-xs text-gray-600">Clips bucket: {String(report.s3?.clips_bucket)}</div>
              {'write_ok' in (report.s3||{}) && (
                <div className="text-xs text-gray-600">Write test: {String(report.s3?.write_ok)}</div>
              )}
            </div>
            <div className="border rounded p-3">
              <div className="font-medium mb-1">Ingestion Service</div>
              <div className={(report.ingestion?.ok ? 'text-green-600':'text-yellow-600')}>{report.ingestion?.ok ? 'Reachable' : 'No response'} ({report.ingestion?.status || 0})</div>
            </div>
            <div className="border rounded p-3">
              <div className="font-medium mb-1">Push Service</div>
              <div className={(report.push_service?.ok ? 'text-green-600':'text-yellow-600')}>{report.push_service?.ok ? 'Reachable' : 'No response'} ({report.push_service?.status || 0})</div>
            </div>
            <div className="border rounded p-3">
              <div className="font-medium mb-1">Media Server</div>
              <div className={(report.media_server?.ok ? 'text-green-600':'text-yellow-600')}>{report.media_server?.ok ? 'Reachable' : 'No response'} ({report.media_server?.status || 0})</div>
            </div>
            {('rabbitmq' in report) && (
              <div className="border rounded p-3">
                <div className="font-medium mb-1">RabbitMQ</div>
                <div className={(report.rabbitmq?.ok ? 'text-green-600':'text-yellow-600')}>{report.rabbitmq?.ok ? 'Reachable' : 'No response'}</div>
              </div>
            )}
            <div className="border rounded p-3">
              <div className="font-medium mb-1">System</div>
              <div className="text-xs text-gray-600">Goroutines: {report.system?.goroutines}</div>
              <div className="text-xs text-gray-600">Mem alloc: {Math.round((report.system?.mem_alloc||0)/1024/1024)} MB</div>
              <div className="text-xs text-gray-600">Mem sys: {Math.round((report.system?.mem_sys||0)/1024/1024)} MB</div>
              {'disk' in report && (
                <div className="text-xs text-gray-600 mt-1">
                  Disk: {Math.round((report.disk?.free||0)/1024/1024/1024)} GB free / {Math.round((report.disk?.total||0)/1024/1024/1024)} GB total
                </div>
              )}
              {'build' in report && (
                <div className="text-xs text-gray-600 mt-1">Build: {report.build?.version || '-'} {report.build?.commit ? `(${report.build.commit})` : ''}</div>
              )}
            </div>
          </div>
        </div>
      )}

      <div className="card">
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
