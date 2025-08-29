export type Role = 'superadmin' | 'company_admin' | 'user'

export const routeRoleMap: { prefix: string; roles: Role[] }[] = [
  { prefix: '/companies', roles: ['superadmin'] },
  { prefix: '/users', roles: ['superadmin', 'company_admin'] },
  { prefix: '/cameras', roles: ['superadmin', 'company_admin', 'user'] },
  { prefix: '/anomalies', roles: ['superadmin', 'company_admin', 'user'] },
  { prefix: '/recordings', roles: ['superadmin', 'company_admin', 'user'] },
  { prefix: '/ingest', roles: ['superadmin', 'company_admin', 'user'] },
  { prefix: '/settings/notifications', roles: ['superadmin', 'company_admin', 'user'] },
]

export function isAllowed(pathname: string, role: Role | undefined): boolean {
  if (!role) return false
  const match = routeRoleMap.find((r) => pathname === r.prefix || pathname.startsWith(r.prefix + '/'))
  if (!match) return true // default: any authenticated
  return match.roles.includes(role)
}
