"use client"
import { useMemo, useState, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { useToast } from '@/components/toast'

type Company = { id: number; name: string }
type Role = 'superadmin' | 'company_admin' | 'user'

export default function NewCamera({ companies, selectedCompanyId, role }: { companies: Company[]; selectedCompanyId: string; role: Role }) {
  const [pending, start] = useTransition()
  const router = useRouter()
  const { notify } = useToast()
  const [name, setName] = useState('')
  const [location, setLocation] = useState('')
  const [streamKey, setStreamKey] = useState('')
  const [rtsp, setRtsp] = useState('')
  const [companyId, setCompanyId] = useState(companies[0]?.id?.toString() || '')
  const [msg, setMsg] = useState<string | null>(null)

  const effectiveCompanyId = useMemo(() => {
    if (role === 'superadmin') {
      return (selectedCompanyId && selectedCompanyId.length > 0) ? selectedCompanyId : (companyId || '')
    }
    // company_admin/user: backend will enforce company from JWT
    return ''
  }, [role, selectedCompanyId, companyId])

  async function create() {
    setMsg(null)
    start(async () => {
      const res = await fetch('/api/proxy/api/cameras', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name,
          location,
          stream_key: streamKey,
          rtsp_source: rtsp,
          // Only superadmin sends company_id; others rely on JWT company
          company_id: role === 'superadmin' && effectiveCompanyId ? parseInt(effectiveCompanyId, 10) : undefined,
        }),
      })
      if (res.ok) {
        setName(''); setLocation(''); setStreamKey(''); setRtsp('')
        notify('Camera created')
        router.refresh()
      } else {
        notify(`Create failed (${res.status})`, 'error')
      }
    })
  }

  return (
    <div className="card text-sm">
      <div className="font-medium mb-2">Add Camera</div>
      <div className="grid md:grid-cols-2 gap-2">
        <input className="input" placeholder="Name" value={name} onChange={(e)=>setName(e.target.value)} />
        <input className="input" placeholder="Location" value={location} onChange={(e)=>setLocation(e.target.value)} />
        <input className="input" placeholder="Stream Key (optional)" value={streamKey} onChange={(e)=>setStreamKey(e.target.value)} />
        <input className="input" placeholder="RTSP Source (optional)" value={rtsp} onChange={(e)=>setRtsp(e.target.value)} />
        {role === 'superadmin' && (!selectedCompanyId || selectedCompanyId.length === 0) ? (
          <select className="select" value={companyId} onChange={(e)=>setCompanyId(e.target.value)}>
            {companies.map((c)=> (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </select>
        ) : null}
      </div>
      <div className="mt-2">
        <button onClick={create} disabled={pending} className="btn btn-primary flex items-center gap-2">
          {pending && <span className="inline-block h-4 w-4 border-2 border-white border-t-transparent rounded-full animate-spin" />}
          <span>Create</span>
        </button>
      </div>
    </div>
  )
}
