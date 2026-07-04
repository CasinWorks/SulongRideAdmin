export type MaintenancePhase = 'inactive' | 'scheduled' | 'active'

export type AppMaintenanceStatus = {
  phase: MaintenancePhase
  id?: string
  title?: string
  message?: string
  starts_at?: string
  ends_at?: string
  block_apps?: boolean
  notify_users?: boolean
}

export type AppMaintenanceRow = {
  id: string
  status: 'scheduled' | 'active' | 'ended' | 'cancelled'
  title: string
  message: string
  starts_at: string
  ends_at: string
  block_apps: boolean
  notify_users: boolean
  ended_early_at: string | null
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

export type ScheduleMaintenanceInput = {
  title: string
  message: string
  starts_at: string
  ends_at: string
  block_apps: boolean
  notify_users: boolean
}
