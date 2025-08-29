"use client"
import { useState, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { useToast } from '@/components/toast'

type Cam = {
  id: number
  name: string
  location?: string
  stream_key?: string
}

export default function CamerasActions({ camera }: { camera: Cam }) {
  const [pending, start] = useTransition()
  const router = useRouter()
  const { notify } = useToast()
  const [open, setOpen] = useState(false)
  const [name, setName] = useState(camera.name)
  const [location, setLocation] = useState(camera.location || '')
  const [streamKey, setStreamKey] = useState(camera.stream_key || '')

  async function save() {
    start(async () => {
      const res = await fetch(`/api/proxy/api/cameras/${camera.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, location, stream_key: streamKey }),
      })
      if (res.ok) { setOpen(false); notify('Camera updated'); router.refresh() }
    })
  }

  async function remove() {
    if (!confirm('Delete this camera?')) return
    start(async () => {
      const res = await fetch(`/api/proxy/api/cameras/${camera.id}`, { method: 'DELETE' })
      if (res.ok) { notify('Camera deleted'); router.refresh() }
    })
  }

  return (
    <div className="text-xs">
      <button className="btn btn-outline py-1" onClick={() => setOpen(true)}>Edit</button>
      <button className="btn btn-danger py-1 ml-2" onClick={remove} disabled={pending}>Delete</button>
      {open && (
        <div className="fixed inset-0 z-50">
          <div className="absolute inset-0 bg-black/50" onClick={()=>setOpen(false)} />
          <div className="absolute inset-0 flex items-center justify-center p-4">
            <div className="bg-white rounded shadow-lg w-full max-w-md p-4">
              <div className="text-sm font-medium mb-2">Edit Camera #{camera.id}</div>
              <div className="grid gap-3 text-sm">
                <div>
                  <label className="block text-xs mb-1">Name</label>
                  <input className="input w-full" value={name} onChange={(e)=>setName(e.target.value)} />
                </div>
                <div>
                  <label className="block text-xs mb-1">Location</label>
                  <input className="input w-full" value={location} onChange={(e)=>setLocation(e.target.value)} />
                </div>
                <div>
                  <label className="block text-xs mb-1">Stream Key (optional)</label>
                  <input className="input w-full" value={streamKey} onChange={(e)=>setStreamKey(e.target.value)} />
                </div>
              </div>
              <div className="mt-4 flex justify-end gap-2">
                <button className="btn" onClick={()=>setOpen(false)}>Cancel</button>
                <button className="btn btn-primary flex items-center gap-2" disabled={pending} onClick={save}>
                  {pending && <span className="inline-block h-4 w-4 border-2 border-white border-t-transparent rounded-full animate-spin" />}
                  <span>Save</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
