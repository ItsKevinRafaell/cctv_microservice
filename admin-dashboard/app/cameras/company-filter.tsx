"use client"
import { useRouter, useSearchParams } from 'next/navigation'

type Company = { id: number; name: string }

export default function CompanyFilter({ companies, selectedCompanyId }: { companies: Company[]; selectedCompanyId: string }) {
  const router = useRouter()
  const search = useSearchParams()
  function onChange(e: React.ChangeEvent<HTMLSelectElement>) {
    const id = e.target.value
    const params = new URLSearchParams(search.toString())
    if (id) params.set('companyId', id); else params.delete('companyId')
    router.push(`/cameras?${params.toString()}`)
  }
  return (
    <div className="flex items-center gap-2 text-sm">
      <span>Company:</span>
      <select className="border rounded px-2 py-1" value={selectedCompanyId} onChange={onChange}>
        <option value="">(select)</option>
        {companies.map((c)=> (
          <option key={c.id} value={c.id}>{c.name}</option>
        ))}
      </select>
    </div>
  )
}

