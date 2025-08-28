import { Skeleton } from '@/components/ui/skeleton'

export default function NotificationsSettingsPage() {
  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Notifications & FCM</h1>
      <div className="space-y-2">
        <Skeleton className="h-10 w-64" />
        <Skeleton className="h-10 w-80" />
        <Skeleton className="h-10 w-56" />
      </div>
    </div>
  )
}

