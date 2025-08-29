"use client"
import { useState, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { useToast } from '@/components/toast'

export default function NewCompany() {
  const [pending, start] = useTransition()
  const [name, setName] = useState('')
  const router = useRouter()
  const { notify } = useToast()
  async function create() {
    start(async () => {
      const res = await fetch('/api/proxy/api/companies', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name })
      })
      if (res.ok) { setName(''); notify('Company created'); router.refresh() }
      else { notify(`Create failed (${res.status})`, 'error') }
    })
  }
  return (
    <div className="card text-sm">
      <div className="font-medium mb-2">Add Company</div>
      <div className="flex gap-2">
        <input className="input flex-1" placeholder="Company name" value={name} onChange={(e)=>setName(e.target.value)} />
        <button onClick={create} disabled={pending} className="btn btn-primary flex items-center gap-2">
          {pending && <span className="inline-block h-4 w-4 border-2 border-white border-t-transparent rounded-full animate-spin" />}
          <span>Create</span>
        </button>
      </div>
    </div>
  )
}
