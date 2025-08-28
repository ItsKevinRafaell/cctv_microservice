import Link from 'next/link'
import { Skeleton } from '@/components/ui/skeleton'

export default function AnomaliesPage() {
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Anomalies</h1>
      <div className="flex gap-2 text-sm">
        <Skeleton className="h-8 w-40" />
        <Skeleton className="h-8 w-40" />
      </div>
      <div className="divide-y border rounded">
        {Array.from({ length: 5 }).map((_, i) => (
          <div key={i} className="p-3 flex items-center justify-between">
            <Skeleton className="h-5 w-64" />
            <Link href={`/anomalies/${i+1}`} className="text-blue-600 text-sm">Detail</Link>
          </div>
        ))}
      </div>
    </div>
  )
}

