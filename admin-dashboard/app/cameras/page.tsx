import { api } from '@/lib/api'
import Link from 'next/link'
import CamerasActions from './cameras-actions'
import NewCamera from './new-camera'

export default async function CamerasPage() {
  const cams = await api.cameras().catch(() => [])
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Cameras</h1>
      <NewCamera />
      <div className="grid gap-3">
        {cams.length === 0 && <div className="text-sm text-gray-600">No cameras</div>}
        {cams.map((c) => (
          <div key={c.id} className="border rounded p-3">
            <div className="font-medium">{c.name}</div>
            <div className="text-xs text-gray-500">Location: {c.location || '-'} • Stream Key: {c.stream_key}</div>
            <div className="text-xs mt-2">
              <div>HLS: <a className="text-blue-600" href={c.hls_url} target="_blank">{c.hls_url}</a></div>
              <div>RTSP: <code>{c.rtsp_url}</code></div>
              <div>WebRTC WS: <code>{c.webrtc_url}</code></div>
            </div>
            <div className="mt-2 text-sm">
              <Link className="text-blue-600" href={`/recordings/${c.id}`}>View recordings</Link>
            </div>
            <div className="mt-2">
              <CamerasActions camera={c} />
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
