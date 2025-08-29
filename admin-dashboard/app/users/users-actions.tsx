"use client"
import { useState, useTransition } from 'react'
import type { User } from '@/lib/api'

export default function UsersActions({ user, viewerRole, selectedCompanyId }: { user: User; viewerRole: 'superadmin' | 'company_admin' | 'user'; selectedCompanyId?: string }) {
  const [pending, startTransition] = useTransition()
  const [role, setRole] = useState(user.role)
  const [email, setEmail] = useState(user.email)
  const [name, setName] = useState(user.name || '')
  const [password, setPassword] = useState('')

  async function updateRole(next: string) {
    // Block demote by company_admin: cannot change company_admin -> user
    if (viewerRole === 'company_admin' && role === 'company_admin' && next === 'user') {
      alert('Company admin tidak boleh demote admin menjadi user.')
      return
    }
    startTransition(async () => {
      const body: any = { role: next }
      if (viewerRole === 'superadmin' && selectedCompanyId) {
        body.company_id = selectedCompanyId
      }
      const res = await fetch(`/api/proxy/api/users/${user.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      })
      if (res.ok) setRole(next)
    })
  }

  async function removeUser() {
    startTransition(async () => {
      const qs = (viewerRole === 'superadmin' && selectedCompanyId) ? `?company_id=${encodeURIComponent(selectedCompanyId)}` : ''
      await fetch(`/api/proxy/api/users/${user.id}${qs}`, { method: 'DELETE' })
      window.location.reload()
    })
  }

  // Unified UI: Edit via popup (modal)
  const [open, setOpen] = useState(false)

  const RoleSelect = () => {
    if (viewerRole === 'superadmin') {
      // Edit mode only allows setting to 'user' or 'company_admin' (no 'superadmin')
      if (user.role === 'superadmin') {
        // If the target is superadmin, keep it read-only to avoid offering a forbidden option
        return <input className="input w-full bg-gray-50 text-gray-600" value="superadmin" readOnly />
      }
      return (
        <select className="select w-full" value={role} onChange={(e)=>setRole(e.target.value)}>
          <option value="user">user</option>
          <option value="company_admin">company_admin</option>
        </select>
      )
    }
    if (viewerRole === 'company_admin') {
      const allowedRoles = user.role === 'company_admin' ? ['company_admin'] : ['user','company_admin']
      return (
        <select className="select w-full" value={role} onChange={(e)=>setRole(e.target.value)}>
          {allowedRoles.map(r => <option key={r} value={r}>{r}</option>)}
        </select>
      )
    }
    return <input className="input w-full bg-gray-50 text-gray-600" value={role} readOnly />
  }

  const canEdit = viewerRole === 'superadmin' ? !!selectedCompanyId : (viewerRole === 'company_admin')

  const save = () => {
    // Prevent demote by company_admin
    if (viewerRole === 'company_admin' && user.role === 'company_admin' && role === 'user') {
      alert('Company admin tidak boleh demote admin menjadi user.')
      return
    }
    startTransition(async () => {
      const body: any = {}
      if (role && role !== user.role) body.role = role
      if (email && email !== user.email) body.email = email
      if (name && name !== (user.name||'')) body.name = name
      if (password) body.password = password
      if (viewerRole === 'superadmin' && selectedCompanyId) body.company_id = selectedCompanyId
      const res = await fetch(`/api/proxy/api/users/${user.id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
      if (res.ok) { setPassword(''); setOpen(false) }
    })
  }

  return (
    <div className="flex items-center gap-2 text-xs">
      <button className="btn btn-outline text-xs" onClick={()=>setOpen(true)} disabled={pending || !canEdit}>Edit</button>
      <button onClick={removeUser} disabled={pending || (viewerRole==='company_admin' && user.role!=='user') || (viewerRole==='superadmin' && !selectedCompanyId)} className="btn btn-danger text-xs">Delete</button>

      {open && (
        <div className="fixed inset-0 z-50">
          <div className="absolute inset-0 bg-black/50" onClick={()=>setOpen(false)} />
          <div className="absolute inset-0 flex items-center justify-center p-4">
            <div className="bg-white rounded shadow-lg w-full max-w-md p-4">
              <div className="text-sm font-medium mb-2">Edit User #{user.id}</div>
              <div className="grid grid-cols-1 gap-3 text-sm">
                <div>
                  <label className="block text-xs mb-1">Name</label>
                  <input className="input w-full" value={name} onChange={(e)=>setName(e.target.value)} />
                </div>
                <div>
                  <label className="block text-xs mb-1">Email</label>
                  <input className="input w-full" value={email} onChange={(e)=>setEmail(e.target.value)} />
                </div>
                <div>
                  <label className="block text-xs mb-1">New Password</label>
                  <input className="input w-full" type="password" value={password} onChange={(e)=>setPassword(e.target.value)} placeholder="(leave blank to keep)" />
                </div>
                <div>
                  <label className="block text-xs mb-1">Role</label>
                  <RoleSelect />
                </div>
              </div>
              <div className="mt-4 flex justify-end gap-2">
                <button className="btn" onClick={()=>setOpen(false)}>Cancel</button>
                <button className="btn btn-primary" disabled={pending || !canEdit} onClick={save}>Save</button>
              </div>
              {viewerRole==='superadmin' && !selectedCompanyId && (
                <div className="mt-2 text-[11px] text-gray-500">Pilih company terlebih dahulu untuk edit.</div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
