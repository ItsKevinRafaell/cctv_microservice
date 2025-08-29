"use client"
import { useState, useTransition } from 'react'
import type { User } from '@/lib/api'

export default function UsersActions({ user }: { user: User }) {
  const [pending, startTransition] = useTransition()
  const [role, setRole] = useState(user.role)

  async function updateRole(next: string) {
    startTransition(async () => {
      const res = await fetch(`/api/proxy/api/users/${user.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ role: next }),
      })
      if (res.ok) setRole(next)
    })
  }

  async function removeUser() {
    startTransition(async () => {
      await fetch(`/api/proxy/api/users/${user.id}`, { method: 'DELETE' })
      window.location.reload()
    })
  }

  return (
    <div className="flex items-center gap-2">
      <span className="text-xs text-gray-600">Role:</span>
      <select
        className="select text-sm"
        value={role}
        onChange={(e) => updateRole(e.target.value)}
        disabled={pending}
      >
        <option value="user">user</option>
        <option value="company_admin">company_admin</option>
        <option value="superadmin">superadmin</option>
      </select>
      <button onClick={removeUser} disabled={pending} className="btn btn-danger text-xs">Delete</button>
    </div>
  )
}
