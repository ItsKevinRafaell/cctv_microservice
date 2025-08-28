import { Skeleton } from '@/components/ui/skeleton'

export default function CompaniesPage() {
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Companies</h1>
      <Skeleton className="h-10 w-48" />
      <div className="grid gap-2">
        {Array.from({ length: 5 }).map((_, i) => (
          <Skeleton key={i} className="h-10 w-full" />
        ))}
      </div>
    </div>
  )
}

