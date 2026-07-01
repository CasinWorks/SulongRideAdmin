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

export type AuditLogRow = {
  id: string
  actor_id: string | null
  actor_email: string | null
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
