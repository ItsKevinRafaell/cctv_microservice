"use client"
import Link from 'next/link'
import { usePathname } from 'next/navigation'

const links = [
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
  return (
    <header className="border-b">
      <div className="max-w-6xl mx-auto p-3 flex items-center justify-between">
        <div className="font-semibold">CCTV Admin</div>
        <nav className="flex gap-4 text-sm">
          {links.map((l) => (
            <Link
              key={l.href}
              href={l.href}
              className={
                "px-2 py-1 rounded hover:bg-gray-100 " +
                (pathname === l.href ? "bg-gray-100 font-medium" : "")
              }
            >
              {l.label}
            </Link>
          ))}
          <form action="/api/auth/logout" method="post">
            <button className="px-2 py-1 rounded bg-red-50 hover:bg-red-100 text-red-700 border border-red-200">
              Logout
            </button>
          </form>
        </nav>
      </div>
    </header>
  )
}

