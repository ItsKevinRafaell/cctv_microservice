"use client"
import { useState, useTransition } from 'react'

type Cam = {
  id: number
  name: string
  location?: string
  stream_key?: string
}

export default function CamerasActions({ camera }: { camera: Cam }) {
  const [pending, start] = useTransition()
  const [name, setName] = useState(camera.name)
  const [location, setLocation] = useState(camera.location || '')
  const [streamKey, setStreamKey] = useState(camera.stream_key || '')
  const [msg, setMsg] = useState<string | null>(null)

  async function update() {
    setMsg(null)
    start(async () => {
      const res = await fetch(`/api/proxy/api/cameras/${camera.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, location, stream_key: streamKey }),
      })
      setMsg(res.ok ? 'Updated' : `Failed (${res.status})`)
    })
  }

  async function remove() {
    if (!confirm('Delete this camera?')) return
    start(async () => {
      const res = await fetch(`/api/proxy/api/cameras/${camera.id}`, { method: 'DELETE' })
      if (res.ok) window.location.reload()
      else setMsg(`Failed (${res.status})`)
    })
  }

  return (
    <div className="border rounded p-2 text-xs flex flex-col gap-2">
      <div className="flex gap-2">
        <input className="input flex-1 py-1" value={name} onChange={(e)=>setName(e.target.value)} placeholder="Name" />
        <input className="input flex-1 py-1" value={location} onChange={(e)=>setLocation(e.target.value)} placeholder="Location" />
      </div>
      <div className="flex gap-2">
        <input className="input flex-1 py-1" value={streamKey} onChange={(e)=>setStreamKey(e.target.value)} placeholder="Stream Key (optional)" />
      </div>
      <div className="flex gap-2">
        <button onClick={update} disabled={pending} className="btn btn-outline py-1">Save</button>
        <button onClick={remove} disabled={pending} className="btn btn-danger py-1">Delete</button>
        {msg && <span className="text-gray-600">{msg}</span>}
      </div>
    </div>
  )
}
