"use client"
import { useState, useTransition } from 'react'

export function CompanyRow({ c }: { c: { id: number; name: string; created_at?: string } }) {
  const [pending, start] = useTransition()
  const [name, setName] = useState(c.name)
  const [msg, setMsg] = useState<string | null>(null)
  async function save() {
    setMsg(null)
    start(async () => {
      const res = await fetch(`/api/proxy/api/companies/${c.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name })
      })
      setMsg(res.ok ? 'Saved' : `Failed (${res.status})`)
    })
  }
  async function remove() {
    if (!confirm('Delete this company?')) return
    start(async () => {
      const res = await fetch(`/api/proxy/api/companies/${c.id}`, { method: 'DELETE' })
      if (res.ok) location.reload(); else setMsg(`Failed (${res.status})`)
    })
  }
  return (
    <div className="p-3 flex items-center justify-between">
      <div>
        <div className="text-xs text-gray-500">ID: {c.id} {c.created_at ? `• ${new Date(c.created_at).toLocaleString()}` : ''}</div>
        <input className="border rounded px-2 py-1 text-sm" value={name} onChange={(e)=>setName(e.target.value)} />
      </div>
      <div className="flex gap-2">
        <button onClick={save} disabled={pending} className="px-2 py-1 border rounded text-sm">Save</button>
        <button onClick={remove} disabled={pending} className="px-2 py-1 border rounded text-sm text-red-600">Delete</button>
        {msg && <span className="text-xs text-gray-600">{msg}</span>}
      </div>
    </div>
  )
}

