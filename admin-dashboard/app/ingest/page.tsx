"use client"
import { useEffect, useState } from 'react'

export default function IngestPage() {
  const [file, setFile] = useState<File | null>(null)
  const [msg, setMsg] = useState<string | null>(null)
  const [role, setRole] = useState<'superadmin'|'company_admin'|'user'|'unknown'>('unknown')

  useEffect(() => {
    let aborted = false
    fetch('/api/auth/me').then(async (r) => {
      if (!r.ok) return
      const j = await r.json().catch(() => null)
      if (!aborted) setRole((j?.role as any) || 'user')
    }).catch(() => {})
    return () => { aborted = true }
  }, [])

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault()
    setMsg(null)
    if (!file) { setMsg('Pilih file dulu'); return }
    const fd = new FormData()
    fd.append('file', file)
    const res = await fetch('/api/proxy-ingest/ingest/video', { method: 'POST', body: fd })
    setMsg(res.ok ? 'Upload OK' : `Gagal (${res.status})`)
  }

  return (
    <div className="space-y-4">
      <h1 className="title">Upload / Ingestion Test</h1>
      {(role === 'superadmin' || role === 'company_admin') ? (
        <form onSubmit={onSubmit} className="space-y-3">
          <input className="input" type="file" accept="video/*" onChange={(e)=>setFile(e.target.files?.[0]||null)} />
          <button type="submit" className="btn btn-primary text-sm">Upload</button>
          {msg && <div className="text-sm text-gray-700">{msg}</div>}
        </form>
      ) : (
        <div className="text-sm text-gray-600">Read-only access. Upload requires admin.</div>
      )}
      <div className="card text-sm text-gray-600">
        Form ini mengirim ke ingestion service via proxy `/api/proxy-ingest/ingest/video`.
      </div>
    </div>
  )
}
