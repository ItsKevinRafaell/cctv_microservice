import { api, User } from '@/lib/api'
import UsersActions from './users-actions'

export default async function UsersPage() {
  const users = await api.users().catch(() => [])
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Users</h1>
      <div className="border rounded divide-y">
        {users.length === 0 && <div className="p-3 text-sm text-gray-600">No users</div>}
        {users.map((u) => (
          <div key={u.id} className="p-3 flex items-center justify-between text-sm">
            <div>
              <div className="font-medium">{u.email}</div>
              <div className="text-xs text-gray-500">ID: {u.id} • Company: {u.company_id}</div>
            </div>
            <UsersActions user={u} />
          </div>
        ))}
      </div>
    </div>
  )
}
