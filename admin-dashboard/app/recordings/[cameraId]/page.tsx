import { Skeleton } from '@/components/ui/skeleton'

export default function CameraRecordingsPage({ params }: { params: { cameraId: string } }) {
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Recordings for {params.cameraId}</h1>
      <div className="flex gap-2">
        <Skeleton className="h-10 w-40" />
        <Skeleton className="h-10 w-40" />
      </div>
      <div className="grid gap-2">
        {Array.from({ length: 8 }).map((_, i) => (
          <Skeleton key={i} className="h-12 w-full" />
        ))}
      </div>
    </div>
  )
}

