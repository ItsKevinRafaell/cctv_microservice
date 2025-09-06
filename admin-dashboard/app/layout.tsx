import './globals.css'
import type { Metadata } from 'next'
import { Suspense } from 'react'
import AppShell from '@/components/app-shell'

export const metadata: Metadata = {
  title: 'Anomeye Dashboard',
  description: 'Admin dashboard for CCTV microservices',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Suspense fallback={null}>
          <AppShell>{children}</AppShell>
        </Suspense>
      </body>
    </html>
  )
}
