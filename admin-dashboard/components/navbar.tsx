"use client"
import Link from 'next/link'
import { useEffect, useMemo, useState } from 'react'
import { usePathname } from 'next/navigation'
import { routeRoleMap, type Role } from '@/lib/roles'

const allLinks = [
  { href: '/', label: 'Status' },
  { href: '/companies', label: 'Companies' },
  { href: '/users', label: 'Users' },
  { href: '/cameras', label: 'Cameras' },
  { href: '/anomalies', label: 'Anomalies' },
  { href: '/ingest', label: 'Ingest' },
  { href: '/settings/notifications', label: 'Notifications' },
]

export function Navbar() {
  const pathname = usePathname()
  const [role, setRole] = useState<Role | undefined>(undefined)

  useEffect(() => {
    let aborted = false
    const load = () => {
      fetch('/api/auth/me', { cache: 'no-store' }).then(async (r) => {
        if (!r.ok) { if (!aborted) setRole(undefined); return }
        const j = await r.json().catch(() => null)
        if (!aborted) setRole(j?.role as Role)
      }).catch(() => { if (!aborted) setRole(undefined) })
    }
    load()
    const onStorage = (e: StorageEvent) => {
      if (e.key === 'auth:changed') load()
    }
    window.addEventListener('storage', onStorage)
    return () => { aborted = true; window.removeEventListener('storage', onStorage) }
  }, [pathname])

  const links = useMemo(() => {
    if (!role) return [] as typeof allLinks
    return allLinks.filter((l) => {
      const match = routeRoleMap.find((r) => l.href === r.prefix)
      if (!match) return true
      return match.roles.includes(role)
    })
  }, [role])

  // Hide navbar on login route (after all hooks are called to keep hook order stable)
  if (pathname.startsWith('/login')) return null

  return (
    <header className="border-b bg-[#0b1b33] text-white">
      <div className="max-w-6xl mx-auto p-3 flex items-center justify-between">
        <div className="font-semibold tracking-wide">CCTV Admin</div>
        <nav className="flex gap-1 text-sm">
          {links.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              className={
                "px-3 py-1 rounded hover:bg-[#11254a] " +
                (pathname === l.href ? "bg-[#122a55] font-medium" : "")
              }
            >
              {l.label}
            </Link>
          ))}
          <form action="/api/auth/logout" method="post">
            <button className="ml-2 px-3 py-1 rounded bg-[#153063] hover:bg-[#193873] text-white border border-[#1d3f80]">
              Logout
            </button>
          </form>
        </nav>
      </div>
    </header>
  )
}
