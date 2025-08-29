import { api } from '@/lib/api'
import { decodeJwt, getToken } from '@/lib/auth'
import Link from 'next/link'
import PageHeader from '@/components/page-header'
import CamerasActions from './cameras-actions'
import NewCamera from './new-camera'
import CompanyFilter from './company-filter'

export default async function CamerasPage({ searchParams }: { searchParams?: { companyId?: string } }) {
  const token = getToken()
  const me = decodeJwt(token)
  const role = (me?.role as 'superadmin' | 'company_admin' | 'user' | undefined) || 'user'
  const companyId = role === 'superadmin' ? (searchParams?.companyId || '') : ''
  const companies = role === 'superadmin' ? await api.companies().catch(() => []) : []
  const cams = await api.cameras(companyId || undefined).catch(() => [])
  return (
    <div className="space-y-4">
      <PageHeader title="Cameras" />
      {role === 'superadmin' && (
        <>
          <CompanyFilter companies={companies} selectedCompanyId={companyId || ''} />
          <NewCamera role={role} companies={companies} selectedCompanyId={companyId || ''} />
        </>
      )}
      <div className="grid gap-3">
        {cams.length === 0 && <div className="text-sm text-gray-600">No cameras</div>}
        {cams.map((c) => (
          <div key={c.id} className="card">
            <div className="font-medium">{c.name}</div>
            <div className="text-xs text-gray-500">Location: {c.location || '-'} • Stream Key: {c.stream_key}</div>
            <div className="text-xs mt-2">
              <div>HLS: <a className="text-blue-600" href={c.hls_url} target="_blank">{c.hls_url}</a></div>
              <div>RTSP: <code>{c.rtsp_url}</code></div>
              <div>WebRTC WS: <code>{c.webrtc_url}</code></div>
            </div>
            <div className="mt-2 text-sm">
              <Link className="text-blue-600" href={`/recordings/${c.id}`}>View recordings</Link>
            </div>
            {role === 'superadmin' && (
              <div className="mt-2">
                <CamerasActions camera={c} />
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}
