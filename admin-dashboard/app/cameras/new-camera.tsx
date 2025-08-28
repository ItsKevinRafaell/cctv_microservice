"use client"
import { useState, useTransition } from 'react'

export default function NewCamera() {
  const [pending, start] = useTransition()
  const [name, setName] = useState('')
  const [location, setLocation] = useState('')
  const [streamKey, setStreamKey] = useState('')
  const [rtsp, setRtsp] = useState('')
  const [msg, setMsg] = useState<string | null>(null)

  async function create() {
    setMsg(null)
    start(async () => {
      const res = await fetch('/api/proxy/api/cameras', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, location, stream_key: streamKey, rtsp_source: rtsp }),
      })
      if (res.ok) {
        setName(''); setLocation(''); setStreamKey(''); setRtsp('')
        setMsg('Created')
        setTimeout(() => window.location.reload(), 700)
      } else {
        setMsg(`Failed (${res.status})`)
      }
    })
  }

  return (
    <div className="border rounded p-3 text-sm">
      <div className="font-medium mb-2">Add Camera</div>
      <div className="grid md:grid-cols-2 gap-2">
        <input className="border rounded px-2 py-1" placeholder="Name" value={name} onChange={(e)=>setName(e.target.value)} />
        <input className="border rounded px-2 py-1" placeholder="Location" value={location} onChange={(e)=>setLocation(e.target.value)} />
        <input className="border rounded px-2 py-1" placeholder="Stream Key (optional)" value={streamKey} onChange={(e)=>setStreamKey(e.target.value)} />
        <input className="border rounded px-2 py-1" placeholder="RTSP Source (optional)" value={rtsp} onChange={(e)=>setRtsp(e.target.value)} />
      </div>
      <div className="mt-2">
        <button onClick={create} disabled={pending} className="px-3 py-1 rounded border">Create</button>
        {msg && <span className="ml-2 text-gray-600">{msg}</span>}
      </div>
    </div>
  )
}

