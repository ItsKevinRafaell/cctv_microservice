import { api } from '@/lib/api'

export default async function AnomalyDetailPage({ params }: { params: { id: string } }) {
  const a = await api.anomaly(params.id)
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Anomaly #{a.id}</h1>
      <div className="grid md:grid-cols-2 gap-4">
        <div className="space-y-1 text-sm">
          <div><span className="text-gray-500">Type:</span> {a.anomaly_type}</div>
          <div><span className="text-gray-500">Confidence:</span> {(a.confidence*100).toFixed(2)}%</div>
          <div><span className="text-gray-500">Camera:</span> {a.camera_id}</div>
          <div><span className="text-gray-500">Reported:</span> {new Date(a.reported_at).toLocaleString()}</div>
          {a.video_clip_url && (
            <div className="mt-2">
              <a className="text-blue-600" href={a.video_clip_url} target="_blank">Open clip</a>
            </div>
          )}
        </div>
        {a.video_clip_url ? (
          <video className="w-full" controls src={a.video_clip_url} />
        ) : (
          <div className="text-sm text-gray-600">No clip available</div>
        )}
      </div>
    </div>
  )
}
