import { Skeleton } from '@/components/ui/skeleton'

export default function AnomalyDetailPage({ params }: { params: { id: string } }) {
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Anomaly #{params.id}</h1>
      <div className="grid md:grid-cols-2 gap-4">
        <div className="space-y-2">
          <Skeleton className="h-6 w-52" />
          <Skeleton className="h-6 w-40" />
          <Skeleton className="h-6 w-60" />
        </div>
        <Skeleton className="h-64 w-full" />
      </div>
    </div>
  )
}

