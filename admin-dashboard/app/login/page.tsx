"use client"
import { useState } from 'react'
import { useRouter } from 'next/navigation'

export default function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const router = useRouter()

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError(null)
    setLoading(true)
    const res = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    })
    if (res.ok) { router.push('/') } else { const t = await res.text(); setError(t || 'Login failed') }
    setLoading(false)
  }

  return (
    <div className="max-w-md mx-auto mt-12 p-6 border rounded shadow-sm">
      <h1 className="text-xl font-semibold mb-4 text-[#0b1b33]">Login</h1>
      <form onSubmit={onSubmit} className="space-y-3">
        <div>
          <label className="block text-sm mb-1">Email</label>
          <input className="input w-full" type="email" value={email} onChange={(e)=>setEmail(e.target.value)} required />
        </div>
        <div>
          <label className="block text-sm mb-1">Password</label>
          <input className="input w-full" type="password" value={password} onChange={(e)=>setPassword(e.target.value)} required />
        </div>
        {error && <div className="text-red-600 text-sm">{error}</div>}
        <button disabled={loading} className="w-full bg-[#153063] hover:bg-[#193873] disabled:opacity-70 text-white py-2 rounded flex items-center justify-center gap-2" type="submit">
          {loading && <span className="inline-block h-4 w-4 border-2 border-white border-t-transparent rounded-full animate-spin" />}
          <span>Sign in</span>
        </button>
      </form>
    </div>
  )
}
