import { Skeleton } from '@/components/ui/skeleton'

export default function CamerasPage() {
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Cameras</h1>
      <div className="grid gap-2">
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton key={i} className="h-24 w-full" />
        ))}
      </div>
    </div>
  )
}

