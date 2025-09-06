"use client"
import { useMemo } from 'react'
import { usePathname } from 'next/navigation'
import Link from 'next/link'

export default function PageHeader({ title }: { title?: string }) {
  const pathname = usePathname()
  const crumbs = useMemo(() => {
    const parts = pathname.split('/').filter(Boolean)
    const acc: { href: string; label: string }[] = []
    let cur = ''
    for (const p of parts) {
      cur += '/' + p
      acc.push({ href: cur, label: p.replace(/\[|\]/g, '') })
    }
    return acc
  }, [pathname])

  const derivedTitle = title || (crumbs.at(-1)?.label || 'Dashboard')

  return (
    <div className="mb-4">
      <div className="text-2xl font-semibold text-[#0b1b33] tracking-tight">{derivedTitle.charAt(0).toUpperCase() + derivedTitle.slice(1)}</div>
      <div className="mt-1 text-xs text-gray-500 flex items-center gap-1">
        <Link className="hover:underline" href="/">Home</Link>
        {crumbs.map((c, i) => (
          <span key={c.href} className="flex items-center gap-1">
            <span>/</span>
            {i === crumbs.length - 1 ? (
              <span className="text-gray-600">{c.label}</span>
            ) : (
              <Link className="hover:underline" href={c.href}>{c.label}</Link>
            )}
          </span>
        ))}
      </div>
    </div>
  )
}

