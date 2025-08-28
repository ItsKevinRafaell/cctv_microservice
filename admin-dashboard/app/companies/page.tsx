import { api } from '@/lib/api'
import NewCompany from './new-company'
import { CompanyRow } from './row'

export default async function CompaniesPage() {
  const companies = await api.companies().catch(() => [])
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Companies</h1>
      <NewCompany />
      <div className="border rounded divide-y">
        {companies.length === 0 && (
          <div className="p-3 text-sm text-gray-600">No companies</div>
        )}
        {companies.map((c) => (
          <CompanyRow key={c.id} c={c} />
        ))}
      </div>
    </div>
  )
}
