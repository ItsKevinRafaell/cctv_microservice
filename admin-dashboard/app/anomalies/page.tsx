import Link from 'next/link'
import { api } from '@/lib/api'

export default async function AnomaliesPage() {
  const items = await api.anomaliesRecent().catch(() => [])
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Anomalies</h1>
      <div className="divide-y border rounded">
        {items.length === 0 && <div className="p-3 text-sm text-gray-600">No recent anomalies</div>}
        {items.map((a) => (
          <div key={a.id} className="p-3 flex items-center justify-between text-sm">
            <div>
              <div className="font-medium">{a.anomaly_type} • {(a.confidence*100).toFixed(1)}%</div>
              <div className="text-xs text-gray-500">Camera #{a.camera_id} • {new Date(a.reported_at).toLocaleString()}</div>
            </div>
            <Link href={`/anomalies/${a.id}`} className="text-blue-600">Detail</Link>
          </div>
        ))}
      </div>
    </div>
  )
}
