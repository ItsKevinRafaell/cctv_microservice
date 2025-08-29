"use client"
import { useState, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { useToast } from '@/components/toast'

export function CompanyRow({ c }: { c: { id: number; name: string; created_at?: string } }) {
  const [pending, start] = useTransition()
  const router = useRouter()
  const { notify } = useToast()
  const [open, setOpen] = useState(false)
  const [name, setName] = useState(c.name)

  async function save() {
    start(async () => {
      const res = await fetch(`/api/proxy/api/companies/${c.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name })
      })
      if (res.ok) { setOpen(false); notify('Company updated'); router.refresh() }
    })
  }
  async function remove() {
    if (!confirm('Delete this company?')) return
    start(async () => {
      const res = await fetch(`/api/proxy/api/companies/${c.id}`, { method: 'DELETE' })
      if (res.ok) { notify('Company deleted'); router.refresh() }
    })
  }
  return (
    <div className="p-3 flex items-center justify-between">
      <div>
        <div className="text-xs text-gray-500">ID: {c.id} {c.created_at ? `• ${new Date(c.created_at).toLocaleString()}` : ''}</div>
        <div className="font-medium">{c.name}</div>
      </div>
      <div className="flex gap-2">
        <button onClick={()=>setOpen(true)} disabled={pending} className="btn btn-outline text-sm">Edit</button>
        <button onClick={remove} disabled={pending} className="btn btn-danger text-sm">Delete</button>
      </div>

      {open && (
        <div className="fixed inset-0 z-50">
          <div className="absolute inset-0 bg-black/50" onClick={()=>setOpen(false)} />
          <div className="absolute inset-0 flex items-center justify-center p-4">
            <div className="bg-white rounded shadow-lg w-full max-w-md p-4">
              <div className="text-sm font-medium mb-2">Edit Company #{c.id}</div>
              <div className="grid gap-3 text-sm">
                <div>
                  <label className="block text-xs mb-1">Name</label>
                  <input className="input w-full" value={name} onChange={(e)=>setName(e.target.value)} />
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
