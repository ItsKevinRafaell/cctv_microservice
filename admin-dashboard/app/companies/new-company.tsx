"use client"
import { useState, useTransition } from 'react'

export default function NewCompany() {
  const [pending, start] = useTransition()
  const [name, setName] = useState('')
  const [msg, setMsg] = useState<string | null>(null)
  async function create() {
    setMsg(null)
    start(async () => {
      const res = await fetch('/api/proxy/api/companies', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name })
      })
      if (res.ok) {
        setName('')
        setMsg('Created')
        setTimeout(()=>location.reload(), 600)
      } else {
        setMsg(`Failed (${res.status})`)
      }
    })
  }
  return (
    <div className="border rounded p-3 text-sm">
      <div className="font-medium mb-2">Add Company</div>
      <div className="flex gap-2">
        <input className="border rounded px-2 py-1 flex-1" placeholder="Company name" value={name} onChange={(e)=>setName(e.target.value)} />
        <button onClick={create} disabled={pending} className="px-3 py-1 border rounded">Create</button>
        {msg && <span className="text-gray-600">{msg}</span>}
      </div>
    </div>
  )
}

