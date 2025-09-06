"use client"
import { useState } from 'react'
import { Sidebar } from '@/components/sidebar'
import { ToastProvider } from '@/components/toast'

export default function AppShell({ children }: { children: React.ReactNode }) {
  const [mobileOpen, setMobileOpen] = useState(false)
  return (
    <ToastProvider>
      <div className="min-h-screen flex bg-slate-50">
        <Sidebar />
        <main className="flex-1 min-w-0">
          {/* Topbar (mobile) */}
          <div className="md:hidden sticky top-0 z-40 bg-white border-b">
            <div className="h-12 px-3 flex items-center gap-2">
              <button
                className="px-2 py-1 rounded border text-sm"
                onClick={() => setMobileOpen(true)}
                aria-label="Open menu"
              >
                ☰
              </button>
              <div className="font-medium">Anomeye</div>
            </div>
          </div>
          <div className="max-w-6xl mx-auto p-4 md:p-6">{children}</div>
        </main>

        {/* Mobile overlay */}
        {mobileOpen && (
          <div className="fixed inset-0 z-50 md:hidden">
            <div className="absolute inset-0 bg-black/50" onClick={() => setMobileOpen(false)} />
            <div className="absolute inset-y-0 left-0 w-64 shadow-xl">
              <Sidebar className="w-64 shrink-0 border-r bg-[#0b1b33] text-gray-100 min-h-screen" onNavigate={() => setMobileOpen(false)} />
            </div>
          </div>
        )}
      </div>
    </ToastProvider>
  )
}
