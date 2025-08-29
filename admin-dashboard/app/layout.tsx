import './globals.css'
import type { Metadata } from 'next'
import { Navbar } from '@/components/navbar'
import { Suspense } from 'react'

export const metadata: Metadata = {
  title: 'CCTV Admin Dashboard',
  description: 'Admin dashboard for CCTV microservices',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Suspense fallback={null}>
          <Navbar />
        </Suspense>
        <main className="max-w-6xl mx-auto p-4">{children}</main>
      </body>
    </html>
  )
}
