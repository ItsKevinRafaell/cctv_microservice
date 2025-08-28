"use client"
import { useState } from 'react'

export default function NotificationsSettingsPage() {
  const [token, setToken] = useState('')
  const [msg, setMsg] = useState<string | null>(null)

  async function save(e: React.FormEvent) {
    e.preventDefault()
    setMsg(null)
    const res = await fetch('/api/proxy/api/users/fcm-token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fcm_token: token }),
    })
    setMsg(res.ok ? 'Saved' : `Failed (${res.status})`)
  }

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Notifications & FCM</h1>
      <form onSubmit={save} className="space-y-2 max-w-xl">
        <label className="block text-sm">FCM Token</label>
        <textarea className="w-full border rounded p-2 h-28" value={token} onChange={(e)=>setToken(e.target.value)} />
        <button className="px-3 py-2 rounded bg-black text-white text-sm" type="submit">Save</button>
        {msg && <div className="text-sm text-gray-600">{msg}</div>}
      </form>
    </div>
  )
}
