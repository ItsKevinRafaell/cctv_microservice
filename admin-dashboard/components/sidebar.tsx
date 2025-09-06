"use client"
import Link from 'next/link'
import { useEffect, useMemo, useState } from 'react'
import { usePathname } from 'next/navigation'
import { routeRoleMap, type Role } from '@/lib/roles'

const allLinks = [
  { href: '/', label: 'Overview', icon: '📊' },
  { href: '/companies', label: 'Companies', icon: '🏢' },
  { href: '/users', label: 'Users', icon: '👥' },
  { href: '/cameras', label: 'Cameras', icon: '🎥' },
  { href: '/anomalies', label: 'Anomalies', icon: '⚠️' },
  { href: '/ingest', label: 'Ingest', icon: '⬆️' },
  { href: '/settings/notifications', label: 'Notifications', icon: '🔔' },
]

export function Sidebar({ className = 'hidden md:flex md:w-64 shrink-0 border-r bg-[#0b1b33] text-gray-100 min-h-screen', onNavigate }: { className?: string; onNavigate?: ()=>void }) {
  const pathname = usePathname()
  const [role, setRole] = useState<Role | undefined>(undefined)
  const [userEmail, setUserEmail] = useState<string>('')

  useEffect(() => {
    let aborted = false
    const load = () => {
      fetch('/api/auth/me', { cache: 'no-store' })
        .then(async (r) => {
          if (!r.ok) { if (!aborted) { setRole(undefined); setUserEmail('') }; return }
          const j = await r.json().catch(() => null)
          if (!aborted) { setRole(j?.role as Role); setUserEmail(j?.email || '') }
        })
        .catch(() => { if (!aborted) { setRole(undefined); setUserEmail('') } })
    }
    load()
    const onStorage = (e: StorageEvent) => { if (e.key === 'auth:changed') load() }
    window.addEventListener('storage', onStorage)
    return () => { aborted = true; window.removeEventListener('storage', onStorage) }
  }, [pathname])

  // Compute links first to keep hook order consistent across renders
  const links = useMemo(() => {
    if (!role) return [] as typeof allLinks
    return allLinks.filter((l) => {
      const match = routeRoleMap.find((r) => l.href === r.prefix)
      if (!match) return true
      return match.roles.includes(role)
    })
  }, [role])

  // Hide on login
  if (pathname.startsWith('/login')) return null

  return (
    <aside className={className}>
      <div className="flex flex-col w-full">
        <div className="h-14 px-4 flex items-center border-b border-white/10">
          <span className="font-semibold tracking-wide">Anomeye</span>
        </div>
        <nav className="flex-1 px-2 py-3 text-sm">
          {links.map((l) => {
            const active = pathname === l.href
            return (
              <Link
                key={l.href}
                href={l.href}
                className={
                  'flex items-center gap-2 px-3 py-2 rounded hover:bg-white/10 ' +
                  (active ? 'bg-white/15 font-medium' : '')
                }
                onClick={() => { onNavigate && onNavigate() }}
              >
                <span aria-hidden>{l.icon}</span>
                <span>{l.label}</span>
              </Link>
            )
          })}
        </nav>
        <div className="mt-auto px-3 py-3 border-t border-white/10 text-xs">
          <div className="text-gray-300 truncate">{userEmail || '—'}</div>
          <div className="text-gray-400 mb-2">{role || '—'}</div>
          <form action="/api/auth/logout" method="post">
            <button className="w-full px-3 py-2 rounded bg-[#153063] hover:bg-[#193873] border border-[#1d3f80]">Logout</button>
          </form>
        </div>
      </div>
    </aside>
  )
}
