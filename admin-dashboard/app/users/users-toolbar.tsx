"use client"
import { useRouter, useSearchParams } from 'next/navigation'
import { useEffect, useMemo, useState } from 'react'

type Company = { id: number; name: string }
type Role = 'superadmin' | 'company_admin' | 'user'

export default function UsersToolbar({ companies, selectedCompanyId, role }: { companies: Company[]; selectedCompanyId: string; role: Role }) {
  const router = useRouter()
  const search = useSearchParams()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  // Local company selection is only used when no company is selected above
  const [companyId, setCompanyId] = useState(companies[0]?.id?.toString() || '')
  const [newUserRole, setNewUserRole] = useState<'user'|'company_admin'|'superadmin'>('user')
  const [msg, setMsg] = useState<string | null>(null)

  // Determine the effective company to use when creating a user
  const effectiveCompanyId = useMemo(() => {
    return (selectedCompanyId && selectedCompanyId.length > 0)
      ? selectedCompanyId
      : (companyId || '')
  }, [selectedCompanyId, companyId])

  // Enforce: superadmin without selected company can only create superadmin
  useEffect(() => {
    if (role === 'superadmin' && (!selectedCompanyId || selectedCompanyId.length === 0)) {
      setNewUserRole('superadmin')
    }
  }, [role, selectedCompanyId])

  function onFilterChange(e: React.ChangeEvent<HTMLSelectElement>) {
    const id = e.target.value
    const params = new URLSearchParams(search.toString())
    if (id) params.set('companyId', id); else params.delete('companyId')
    router.push(`/users?${params.toString()}`)
  }

  async function createUser(e: React.FormEvent) {
    e.preventDefault()
    setMsg(null)
    const payload: any = { email, password, role: newUserRole }
    if (role === 'superadmin' && effectiveCompanyId) {
      // Only superadmin may explicitly set company_id when a company is selected
      payload.company_id = parseInt(effectiveCompanyId, 10)
    }
    const res = await fetch('/api/proxy/api/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    })
    if (res.ok) { setMsg('Created'); setEmail(''); setPassword('') } else { setMsg(`Failed (${res.status})`) }
  }

  return (
    <div className="card flex flex-col gap-3">
      {role === 'superadmin' && (
        <div className="flex items-center gap-2 text-sm">
          <span>Company:</span>
          <select className="select" value={selectedCompanyId} onChange={onFilterChange}>
            <option value="">(select)</option>
            {companies.map((c)=> (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </select>
        </div>
      )}
      <form onSubmit={createUser} className="grid md:grid-cols-4 gap-2 items-end">
        <div>
          <label className="block text-xs">Email</label>
          <input className="input w-full" value={email} onChange={(e)=>setEmail(e.target.value)} required />
        </div>
        <div>
          <label className="block text-xs">Password</label>
          <input className="input w-full" type="password" value={password} onChange={(e)=>setPassword(e.target.value)} required />
        </div>
        {(role === 'superadmin' && (!selectedCompanyId || selectedCompanyId.length === 0)) ? (
          <div>
            <label className="block text-xs">Company</label>
            <select className="select w-full" value={companyId} onChange={(e)=>setCompanyId(e.target.value)}>
              {companies.map((c)=> (
                <option key={c.id} value={c.id}>{c.name}</option>
              ))}
            </select>
          </div>
        ) : null}
        <div>
          <label className="block text-xs">Role</label>
          {role === 'superadmin' ? (
            <select
              className="select w-full"
              value={(selectedCompanyId ? newUserRole : 'superadmin')}
              onChange={(e)=>setNewUserRole(e.target.value as any)}
            >
              {selectedCompanyId ? (
                <>
                  <option value="user">user</option>
                  <option value="company_admin">company_admin</option>
                </>
              ) : (
                <option value="superadmin">superadmin</option>
              )}
            </select>
          ) : (
            // company_admin and user may only create basic users
            <input className="input w-full bg-gray-50 text-gray-600" value="user" readOnly />
          )}
        </div>
        <div>
          <button className="btn btn-primary" type="submit">Create User</button>
          {msg && <span className="ml-2 text-xs text-gray-600">{msg}</span>}
        </div>
      </form>
    </div>
  )
}
