import { api } from '@/lib/api'
import Link from 'next/link'

export default async function CameraRecordingsPage({ params }: { params: { cameraId: string } }) {
  const data = await api.cameraRecordings(params.cameraId, { presign: true }).catch(() => ({ camera_id: params.cameraId, from: '', to: '', count: 0, items: [] }))
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Recordings for {params.cameraId}</h1>
      <div className="text-xs text-gray-500">Window: {data.from && new Date(data.from).toLocaleString()} - {data.to && new Date(data.to).toLocaleString()} • {data.count} items</div>
      <div className="border rounded divide-y">
        {data.items.length === 0 && <div className="p-3 text-sm text-gray-600">No recordings found</div>}
        {data.items.map((r) => (
          <div key={r.key} className="p-3 flex items-center justify-between text-sm">
            <div>
              <div className="font-medium">{r.key}</div>
              <div className="text-xs text-gray-500">{r.size ? `${(r.size/1024/1024).toFixed(1)} MB` : ''}</div>
            </div>
            {r.url ? <a className="text-blue-600" href={r.url} target="_blank">Play</a> : <span className="text-gray-400">No URL</span>}
          </div>
        ))}
      </div>
    </div>
  )}
