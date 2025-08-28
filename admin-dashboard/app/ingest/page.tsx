import { Skeleton } from '@/components/ui/skeleton'

export default function IngestPage() {
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Upload / Ingestion Test</h1>
      <div className="space-y-2">
        <Skeleton className="h-10 w-full" />
        <Skeleton className="h-10 w-56" />
      </div>
      <div className="border rounded p-4 text-sm text-gray-600">
        Form upload akan diarahkan ke /ingest/video melalui proxy.
      </div>
    </div>
  )
}

