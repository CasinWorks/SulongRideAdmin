import type {
  DriverRow,
  FareConfig,
  FareSchedule,
  FareScheduleType,
  OperatorApprovalStatus,
  OperatorRole,
  OperatorRow,
  TripRow,
} from '../types'

export const DEFAULT_FARE = {
  baseFare: 40,
  perKmRate: 0,
  minimumFare: 40,
  currency: 'PHP',
} as const

export function mapDriver(row: Record<string, unknown>): DriverRow {
  return {
    id: row.id as string,
    full_name: (row.full_name as string) ?? '',
    email: (row.email as string) ?? '',
    phone: (row.phone as string) ?? null,
    trike_plate_number: (row.trike_plate_number as string) ?? null,
    trike_model: (row.trike_model as string) ?? null,
    approval_status: (row.approval_status as string) ?? 'pending',
    created_at: (row.created_at as string) ?? null,
    is_online: (row.is_online as boolean) ?? false,
    is_available: (row.is_available as boolean) ?? false,
    employment_type: (row.employment_type as string) ?? 'contractual',
    station: (row.station as string) ?? 'Carmona Central',
    shift_schedule: (row.shift_schedule as string) ?? '—',
    shift_days: Array.isArray(row.shift_days)
      ? (row.shift_days as number[]).map((n) => Number(n))
      : [1, 2, 3, 4, 5, 6],
    shift_start: (row.shift_start as string) ?? '06:00:00',
    shift_end: (row.shift_end as string) ?? '14:00:00',
    emergency_contact: (row.emergency_contact as string) ?? '',
    start_date: (row.start_date as string) ?? null,
  }
}

export function mapTrip(row: Record<string, unknown>): TripRow {
  const tags = row.complaint_tags
  return {
    id: row.id as string,
    driver_id: (row.driver_id as string) ?? null,
    pickup_address: (row.pickup_address as string) ?? '',
    dropoff_address: (row.dropoff_address as string) ?? '',
    fare: Number(row.fare ?? 0),
    status: (row.status as string) ?? '',
    created_at: row.created_at as string,
    completed_at: (row.completed_at as string) ?? null,
    rating: row.rating != null ? Number(row.rating) : null,
    review_text: (row.review_text as string) ?? null,
    complaint_tags: Array.isArray(tags) ? tags.map(String) : null,
    review_acknowledged_at: (row.review_acknowledged_at as string) ?? null,
  }
}

export function mapOperator(row: Record<string, unknown>): OperatorRow {
  return {
    id: row.id as string,
    email: (row.email as string) ?? '',
    full_name: (row.full_name as string) ?? '',
    approval_status: (row.approval_status as OperatorApprovalStatus) ?? 'pending',
    role: (row.role as OperatorRole) ?? 'admin',
    approved_by: (row.approved_by as string) ?? null,
    approved_at: (row.approved_at as string) ?? null,
    created_at: (row.created_at as string) ?? null,
  }
}

export function mapFareConfig(row: Record<string, unknown>): FareConfig {
  return {
    id: row.id as string,
    base_fare: Number(row.base_fare ?? DEFAULT_FARE.baseFare),
    per_km_rate: Number(row.per_km_rate ?? DEFAULT_FARE.perKmRate),
    minimum_fare: Number(row.minimum_fare ?? DEFAULT_FARE.minimumFare),
    currency: (row.currency as string) ?? DEFAULT_FARE.currency,
    is_active: (row.is_active as boolean) ?? true,
    updated_at: (row.updated_at as string) ?? null,
  }
}

export function mapFareSchedule(row: Record<string, unknown>): FareSchedule {
  return {
    id: row.id as string,
    label: (row.label as string) ?? '',
    base_fare: Number(row.base_fare ?? DEFAULT_FARE.baseFare),
    per_km_rate: Number(row.per_km_rate ?? DEFAULT_FARE.perKmRate),
    minimum_fare: Number(row.minimum_fare ?? DEFAULT_FARE.minimumFare),
    currency: (row.currency as string) ?? DEFAULT_FARE.currency,
    schedule_type: (row.schedule_type as FareScheduleType) ?? 'discount',
    starts_at: row.starts_at as string,
    ends_at: (row.ends_at as string) ?? null,
    is_active: (row.is_active as boolean) ?? true,
    created_by: (row.created_by as string) ?? null,
    created_at: (row.created_at as string) ?? '',
    updated_at: (row.updated_at as string) ?? '',
  }
}
