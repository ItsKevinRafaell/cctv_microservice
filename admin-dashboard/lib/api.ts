import { authHeaderFromCookie, uploadBaseUrl } from '@/lib/auth'

const API = process.env.API_BASE_URL || 'http://localhost:8080'

async function get<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(API + path, {
    ...init,
    headers: { ...(init?.headers || {}), ...authHeaderFromCookie() },
    cache: 'no-store',
  })
  if (!res.ok) throw new Error(`GET ${path} -> ${res.status}`)
  return res.json()
}

function asArray<T>(val: any): T[] {
  if (Array.isArray(val)) return val as T[]
  return []
}

export type Company = { id: number; name: string; created_at?: string }
export type User = { id: number; email: string; role: string; company_id: number; name?: string }
export type Camera = {
  id: number
  name: string
  location?: string
  stream_key?: string
  hls_url?: string
  rtsp_url?: string
  webrtc_url?: string
}
export type Anomaly = {
  id: number
  camera_id: number
  anomaly_type: string
  confidence: number
  video_clip_url?: string
  reported_at: string
}
export type Recording = {
  key: string
  size: number
  url?: string
}

export type RecordingList = {
  camera_id: string
  from: string
  to: string
  count: number
  items: Recording[]
}

export const api = {
  companies: async () => asArray<Company>(await get<any>(`/api/companies`).catch(() => [])),
  users: async (companyId?: string) => {
    const qs = companyId ? `?company_id=${encodeURIComponent(companyId)}` : ''
    return asArray<User>(await get<any>(`/api/users${qs}`).catch(() => []))
  },
  cameras: async (companyId?: string) => {
    const qs = companyId ? `?company_id=${encodeURIComponent(companyId)}` : ''
    return asArray<Camera>(await get<any>(`/api/cameras${qs}`).catch(() => []))
  },
  anomaliesRecent: async () => asArray<Anomaly>(await get<any>(`/api/anomalies/recent`).catch(() => [])),
  anomaly: (id: string) => get<Anomaly>(`/api/anomalies/${id}`),
  cameraRecordings: async (cameraId: string, params?: { from?: string; to?: string; presign?: boolean }) => {
    const qs = new URLSearchParams()
    if (params?.from) qs.set('from', params.from)
    if (params?.to) qs.set('to', params.to)
    if (params?.presign) qs.set('presign', '1')
    const path = `/api/cameras/${cameraId}/recordings` + (qs.toString() ? `?${qs.toString()}` : '')
    const res = await fetch((process.env.API_BASE_URL || 'http://localhost:8080') + path, {
      headers: { ...authHeaderFromCookie() },
      cache: 'no-store',
    })
    if (!res.ok) throw new Error(`GET ${path} -> ${res.status}`)
    const data = (await res.json()) as RecordingList
    // normalize
    if (!Array.isArray(data?.items)) data.items = []
    return data
  },
}
