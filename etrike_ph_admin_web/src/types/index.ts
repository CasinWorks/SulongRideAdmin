export type OperatorApprovalStatus = 'pending' | 'approved' | 'revoked'
export type OperatorRole = 'super_admin' | 'admin' | 'viewer' | 'hr' | 'dispatcher'

export type OperatorRow = {
  id: string
  email: string
  full_name: string
  approval_status: OperatorApprovalStatus
  role: OperatorRole
  approved_by: string | null
  approved_at: string | null
  created_at: string | null
}

export type OperatorInviteStatus = 'pending' | 'accepted' | 'revoked' | 'expired'

export type OperatorInviteRow = {
  id: string
  token: string
  email: string
  role: OperatorRole
  status: OperatorInviteStatus
  invited_by: string | null
  created_at: string
  expires_at: string
  accepted_at: string | null
  accepted_by: string | null
}

export type OperatorInvitePreview = {
  email: string
  role: OperatorRole
  status: OperatorInviteStatus
  expires_at: string
  accepted_at: string | null
}

export type DriverRow = {
  id: string
  full_name: string
  email: string
  phone: string | null
  trike_plate_number: string | null
  trike_model: string | null
  approval_status: string
  created_at: string | null
  is_online: boolean
  is_available: boolean
  employment_type: string
  station: string
  shift_schedule: string
  shift_days: number[]
  shift_start: string
  shift_end: string
  emergency_contact: string
  start_date: string | null
}

export type FareConfig = {
  id: string
  base_fare: number
  per_km_rate: number
  minimum_fare: number
  currency: string
  is_active: boolean
  updated_at: string | null
}

export type FareScheduleType = 'discount' | 'override'

export type FareSchedule = {
  id: string
  label: string
  base_fare: number
  per_km_rate: number
  minimum_fare: number
  currency: string
  schedule_type: FareScheduleType
  starts_at: string
  ends_at: string | null
  is_active: boolean
  created_by: string | null
  created_at: string
  updated_at: string
}

export type VehicleTypeRow = {
  id: string
  name: string
  description: string
  icon: string
  eta_minutes: number
  sort_order: number
  is_active: boolean
  updated_at: string | null
}

export type EffectiveFare = FareConfig & {
  fare_source: 'default' | 'schedule'
  schedule_id: string | null
  schedule_label: string | null
}

export type AuditLogFilters = {
  search?: string
  dateFrom?: string
  dateTo?: string
  action?: string
  appSource?: string
  actorRole?: string
  limit?: number
}

export type AuditLogRow = {
  id: string
  actor_id: string | null
  actor_email: string | null
  actor_name: string | null
  actor_role: string | null
  action: string
  entity_type: string | null
  entity_id: string | null
  summary: string
  metadata: Record<string, unknown>
  app_source: string | null
  created_at: string
}

export type LeaveRow = {
  id: string
  driver_id: string
  leave_type: string
  start_date: string
  end_date: string
  status: string
  reason: string | null
  created_at: string
  drivers?: { full_name: string; email: string } | null
}

export type AttendanceRow = {
  id: string
  driver_id: string
  clock_in: string
  clock_out: string | null
  drivers?: { full_name: string; email: string } | null
}

export type TripRow = {
  id: string
  driver_id: string | null
  pickup_address: string
  dropoff_address: string
  fare: number
  status: string
  created_at: string
  completed_at: string | null
  rating: number | null
  review_text: string | null
  complaint_tags: string[] | null
  review_acknowledged_at: string | null
}

export type DailyTripCount = {
  date: string
  count: number
  label: string
}

export type DriverStatusBreakdown = {
  onDuty: number
  offDuty: number
  onLeave: number
  pending: number
}

export type FlaggedItem = {
  title: string
  subtitle: string
  borderColor: string
  tab?: string
  driverId?: string
}

export type FleetOverview = {
  activeDrivers: number
  pendingApproval: number
  tripsToday: number
  tripsYesterday: number
  faresToday: number
  avgFareToday: number
  driversOnDuty: number
  tripsLast7Days: DailyTripCount[]
  driverStatus: DriverStatusBreakdown
  flaggedItems: FlaggedItem[]
  topDriversThisWeek: { id: string; name: string; trips: number }[]
}

export type DriverProfile = {
  id: string
  fullName: string
  email: string
  phone: string
  plate: string
  statusLabel: string
  approvalStatus: string
  overallRating: number
  totalTrips: number
  tripsThisMonth: number
  totalEarnings: number
  recentTrips: TripRow[]
  lowRatingReviews: TripRow[]
  activityLog: { date: string; action: string }[]
}

export type DashboardTab =
  | 'overview'
  | 'drivers'
  | 'pending'
  | 'approved'
  | 'revoked'
  | 'attendance'
  | 'leave'
  | 'fare'
  | 'audit'
  | 'team'
