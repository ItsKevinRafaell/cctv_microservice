"use client"
import { useEffect, useState, useCallback } from 'react'
import PageHeader from '@/components/page-header'

export default function IngestPage() {
  const [file, setFile] = useState<File | null>(null)
  const [msg, setMsg] = useState<string | null>(null)
  const [role, setRole] = useState<'superadmin'|'company_admin'|'user'|'unknown'>('unknown')
  const [cameras, setCameras] = useState<Array<{ id: number; name: string; stream_key?: string; location?: string }>>([])
  const [cameraId, setCameraId] = useState<string>('')
  const [isSubmitting, setSubmitting] = useState(false)
  const [loadingCameras, setLoadingCameras] = useState(false)
  const [companies, setCompanies] = useState<Array<{ id: number; name: string }>>([])
  const [companyId, setCompanyId] = useState<string>('')
  const [loadingCompanies, setLoadingCompanies] = useState(false)

  useEffect(() => {
    let aborted = false
    fetch('/api/auth/me').then(async (r) => {
      if (!r.ok) return
      const j = await r.json().catch(() => null)
      if (!aborted) setRole((j?.role as any) || 'user')
    }).catch(() => {})
    return () => { aborted = true }
  }, [])

  const loadCameras = useCallback(async (targetCompanyId?: string) => {
    let url = '/api/proxy/api/cameras'
    if (targetCompanyId) {
      const params = new URLSearchParams({ company_id: targetCompanyId })
      url = `${url}?${params.toString()}`
    }
    setLoadingCameras(true)
    try {
      const res = await fetch(url)
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      const items = await res.json()
      if (Array.isArray(items)) {
        setCameras(items)
        if (items.length > 0) {
          setCameraId(String(items[0].id))
        } else {
          setCameraId('')
        }
      } else {
        throw new Error('Unexpected response')
      }
    } catch (err) {
      console.error('Failed to load cameras', err)
      setMsg('Gagal memuat daftar kamera')
      setCameras([])
      setCameraId('')
    } finally {
      setLoadingCameras(false)
    }
  }, [])

  useEffect(() => {
    if (role === 'company_admin') {
      void loadCameras()
    }
  }, [role, loadCameras])

  useEffect(() => {
    if (role !== 'superadmin') return
    let aborted = false
    setLoadingCompanies(true)
    fetch('/api/proxy/api/companies')
      .then(async (r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`)
        const items = await r.json()
        if (!aborted && Array.isArray(items)) {
          setCompanies(items)
          if (items.length > 0) {
            const first = String(items[0].id)
            setCompanyId(first)
          }
        }
      })
      .catch((err) => {
        console.error('Failed to load companies', err)
        if (!aborted) setMsg('Gagal memuat daftar perusahaan')
      })
      .finally(() => { if (!aborted) setLoadingCompanies(false) })
    return () => { aborted = true }
  }, [role, loadCameras])

  useEffect(() => {
    if (role === 'superadmin' && companyId) {
      void loadCameras(companyId)
    }
  }, [role, companyId, loadCameras])

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (isSubmitting) return
    setMsg(null)
    if (!file) { setMsg('Pilih file dulu'); return }
    if (!cameraId) { setMsg('Pilih kamera tujuan'); return }
    const fd = new FormData()
    fd.append('video_clip', file)
    fd.append('camera_id', cameraId)
    setSubmitting(true)
    try {
      const res = await fetch('/api/proxy-ingest/ingest/video', { method: 'POST', body: fd })
      if (!res.ok) {
        const text = await res.text().catch(() => '')
        setMsg(text ? `Gagal (${res.status}) ${text}` : `Gagal (${res.status})`)
      } else {
        setMsg('Upload OK')
        setFile(null)
      }
    } catch {
      setMsg('Gagal (network error)')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="space-y-4">
      <PageHeader title="Ingest" />
      {(role === 'superadmin' || role === 'company_admin') ? (
        <form onSubmit={onSubmit} className="space-y-3">
          {role === 'superadmin' && (
            <label className="block text-sm font-medium text-gray-700">
              Perusahaan
              <select
                className="input mt-1"
                value={companyId}
                onChange={(e)=>setCompanyId(e.target.value)}
                disabled={loadingCompanies || companies.length === 0}
              >
                {companies.length === 0 && <option value="">(Tidak ada data)</option>}
                {companies.map((company) => (
                  <option key={company.id} value={company.id}>{company.name}</option>
                ))}
              </select>
            </label>
          )}
          <label className="block text-sm font-medium text-gray-700">
            Kamera tujuan
            <select
              className="input mt-1"
              value={cameraId}
              onChange={(e)=>setCameraId(e.target.value)}
              disabled={loadingCameras || cameras.length === 0}
            >
              {cameras.map((cam) => (
                <option key={cam.id} value={cam.id}>
                  {cam.name} {cam.stream_key ? `(${cam.stream_key})` : ''}
                </option>
              ))}
            </select>
          </label>
          <label className="block text-sm font-medium text-gray-700">
            Video clip
            <input
              className="input mt-1"
              type="file"
              accept="video/*"
              onChange={(e)=>setFile(e.target.files?.[0]||null)}
            />
          </label>
          <button type="submit" className="btn btn-primary text-sm" disabled={isSubmitting || loadingCameras}>
            {isSubmitting ? 'Uploading...' : 'Upload'}
          </button>
          {msg && <div className="text-sm text-gray-700">{msg}</div>}
        </form>
      ) : (
        <div className="text-sm text-gray-600">Read-only access. Upload requires admin.</div>
      )}
      <div className="card text-sm text-gray-600">
        Form ini mengirim ke ingestion service via proxy `/api/proxy-ingest/ingest/video`.
      </div>
    </div>
  )
}
