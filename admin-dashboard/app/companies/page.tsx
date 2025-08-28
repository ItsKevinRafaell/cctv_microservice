import { api } from '@/lib/api'

export default async function CompaniesPage() {
  const companies = await api.companies().catch(() => [])
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Companies</h1>
      <div className="border rounded divide-y">
        {companies.length === 0 && (
          <div className="p-3 text-sm text-gray-600">No companies</div>
        )}
        {companies.map((c) => (
          <div key={c.id} className="p-3 flex items-center justify-between">
            <div>
              <div className="font-medium">{c.name}</div>
              <div className="text-xs text-gray-500">ID: {c.id} {c.created_at ? `• ${new Date(c.created_at).toLocaleString()}` : ''}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
