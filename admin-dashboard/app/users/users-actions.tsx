"use client"
import { useState, useTransition } from 'react'
import type { User } from '@/lib/api'

export default function UsersActions({ user, viewerRole, selectedCompanyId }: { user: User; viewerRole: 'superadmin' | 'company_admin' | 'user'; selectedCompanyId?: string }) {
  const [pending, startTransition] = useTransition()
  const [role, setRole] = useState(user.role)

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

  // Superadmin: full control; Company admin: manage only 'user' accounts; User: no actions
  if (viewerRole === 'superadmin') {
    const disabledByNoCompany = !selectedCompanyId
    return (
      <div className="flex items-center gap-2">
        <span className="text-xs text-gray-600">Role:</span>
        <select
          className="select text-sm"
          value={role}
          onChange={(e) => updateRole(e.target.value)}
          disabled={pending || disabledByNoCompany}
        >
          <option value="user">user</option>
          <option value="company_admin">company_admin</option>
          <option value="superadmin">superadmin</option>
        </select>
        <button onClick={removeUser} disabled={pending || disabledByNoCompany} className="btn btn-danger text-xs">Delete</button>
        {disabledByNoCompany && (
          <span className="text-[11px] text-gray-500">Select a company to edit</span>
        )}
      </div>
    )
  }

  if (viewerRole === 'company_admin') {
    const manageable = user.role === 'user'
    const allowedRoles = user.role === 'company_admin' ? ['company_admin'] : ['user', 'company_admin']
    return (
      <div className="flex items-center gap-2">
        <span className="text-xs text-gray-600">Role:</span>
        <select
          className="select text-sm"
          value={role}
          onChange={(e) => updateRole(e.target.value)}
          disabled={pending}
        >
          {allowedRoles.map((r) => (
            <option key={r} value={r}>{r}</option>
          ))}
        </select>
        <button onClick={removeUser} disabled={pending || !manageable} className="btn btn-danger text-xs">Delete</button>
      </div>
    )
  }

  return null
}
