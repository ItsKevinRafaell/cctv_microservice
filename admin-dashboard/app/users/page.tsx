import { api, User } from '@/lib/api'
import { decodeJwt, getToken } from '@/lib/auth'
import UsersActions from './users-actions'
import PageHeader from '@/components/page-header'
import UsersToolbar from './users-toolbar'

export default async function UsersPage({ searchParams }: { searchParams?: { companyId?: string } }) {
  const companyId = searchParams?.companyId
  const token = getToken()
  const me = decodeJwt(token)
  const role = (me?.role as 'superadmin' | 'company_admin' | 'user' | undefined) || 'user'

  const companies = role === 'superadmin' ? await api.companies().catch(() => []) : []
  // Determine which companyId should be used for filtering and form defaults
  const effectiveCompanyId = role === 'superadmin' ? (companyId || '') : ''

  const users = await api.users(effectiveCompanyId || undefined).catch(() => [])
  return (
    <div className="space-y-4">
      <PageHeader title="Users" />
      <UsersToolbar
        role={role}
        companies={companies}
        selectedCompanyId={effectiveCompanyId}
      />
      <div className="border rounded divide-y">
        {users.length === 0 && <div className="p-3 text-sm text-gray-600">No users</div>}
        {users.map((u) => (
          <div key={u.id} className="p-3 flex items-center justify-between text-sm">
            <div>
              <div className="font-medium">{u.email}</div>
              <div className="text-xs text-gray-500">ID: {u.id} • Company: {u.company_id}</div>
            </div>
            <UsersActions user={u} viewerRole={role} selectedCompanyId={effectiveCompanyId} />
          </div>
        ))}
      </div>
    </div>
  )
}
