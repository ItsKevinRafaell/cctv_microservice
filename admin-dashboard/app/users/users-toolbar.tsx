"use client"
import { useRouter, useSearchParams } from 'next/navigation'
import { useState } from 'react'

type Company = { id: number; name: string }

export default function UsersToolbar({ companies, selectedCompanyId }: { companies: Company[]; selectedCompanyId: string }) {
  const router = useRouter()
  const search = useSearchParams()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [companyId, setCompanyId] = useState(selectedCompanyId || (companies[0]?.id?.toString() || ''))
  const [role, setRole] = useState<'user'|'company_admin'|'superadmin'>('user')
  const [msg, setMsg] = useState<string | null>(null)

  function onFilterChange(e: React.ChangeEvent<HTMLSelectElement>) {
    const id = e.target.value
    const params = new URLSearchParams(search.toString())
    if (id) params.set('companyId', id); else params.delete('companyId')
    router.push(`/users?${params.toString()}`)
  }

  async function createUser(e: React.FormEvent) {
    e.preventDefault()
    setMsg(null)
    const res = await fetch('/api/proxy/api/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, company_id: parseInt(companyId, 10), role })
    })
    if (res.ok) { setMsg('Created'); setEmail(''); setPassword('') } else { setMsg(`Failed (${res.status})`) }
  }

  return (
    <div className="flex flex-col gap-3 border rounded p-3">
      <div className="flex items-center gap-2 text-sm">
        <span>Company:</span>
        <select className="border rounded px-2 py-1" value={selectedCompanyId} onChange={onFilterChange}>
          <option value="">(select)</option>
          {companies.map((c)=> (
            <option key={c.id} value={c.id}>{c.name}</option>
          ))}
        </select>
      </div>
      <form onSubmit={createUser} className="grid md:grid-cols-4 gap-2 items-end">
        <div>
          <label className="block text-xs">Email</label>
          <input className="border rounded px-2 py-1 w-full" value={email} onChange={(e)=>setEmail(e.target.value)} required />
        </div>
        <div>
          <label className="block text-xs">Password</label>
          <input className="border rounded px-2 py-1 w-full" type="password" value={password} onChange={(e)=>setPassword(e.target.value)} required />
        </div>
        <div>
          <label className="block text-xs">Company</label>
          <select className="border rounded px-2 py-1 w-full" value={companyId} onChange={(e)=>setCompanyId(e.target.value)}>
            {companies.map((c)=> (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-xs">Role</label>
          <select className="border rounded px-2 py-1 w-full" value={role} onChange={(e)=>setRole(e.target.value as any)}>
            <option value="user">user</option>
            <option value="company_admin">company_admin</option>
            <option value="superadmin">superadmin</option>
          </select>
        </div>
        <div>
          <button className="px-3 py-2 rounded border" type="submit">Create User</button>
          {msg && <span className="ml-2 text-xs text-gray-600">{msg}</span>}
        </div>
      </form>
    </div>
  )
}

