"use client"
import { useState } from 'react'

export default function IngestPage() {
  const [file, setFile] = useState<File | null>(null)
  const [msg, setMsg] = useState<string | null>(null)

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
      <form onSubmit={onSubmit} className="space-y-3">
        <input className="input" type="file" accept="video/*" onChange={(e)=>setFile(e.target.files?.[0]||null)} />
        <button type="submit" className="btn btn-primary text-sm">Upload</button>
        {msg && <div className="text-sm text-gray-700">{msg}</div>}
      </form>
      <div className="card text-sm text-gray-600">
        Form ini mengirim ke ingestion service via proxy `/api/proxy-ingest/ingest/video`.
      </div>
    </div>
  )
}
