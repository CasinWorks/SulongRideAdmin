export type VehicleStatus = 'available' | 'assigned' | 'maintenance' | 'retired'

export type AssignmentStatus = 'scheduled' | 'active' | 'ended' | 'cancelled'

export type MaintenanceType =
  | 'general'
  | 'battery'
  | 'tires'
  | 'brakes'
  | 'electrical'
  | 'body'
  | 'inspection'

export type FleetVehicle = {
  id: string
  unit_number: string
  plate_number: string
  model: string | null
  color: string | null
  year_manufactured: number | null
  status: VehicleStatus
  assigned_driver_id: string | null
  boundary_fee: number
  notes: string | null
  assigned_at: string | null
  last_maintenance_at: string | null
  next_maintenance_due: string | null
  created_at: string
  updated_at: string
}

export type FleetVehicleWithDriver = FleetVehicle & {
  assigned_driver_name: string | null
  assigned_driver_email: string | null
}

export type VehicleAssignmentRow = {
  id: string
  vehicle_id: string
  driver_id: string
  status: AssignmentStatus
  effective_from: string
  effective_to: string | null
  assigned_by: string | null
  notes: string | null
  created_at: string
  updated_at: string
  driver_name?: string
  driver_email?: string
  unit_number?: string
  plate_number?: string
}

export type VehicleMaintenanceLog = {
  id: string
  vehicle_id: string
  logged_by: string | null
  maintenance_type: MaintenanceType
  description: string
  cost: number | null
  odometer_km: number | null
  performed_at: string
  next_due_date: string | null
  created_at: string
}

export type VehicleFormInput = {
  unit_number: string
  plate_number: string
  model?: string
  color?: string
  year_manufactured?: number | null
  boundary_fee?: number
  status?: VehicleStatus
  notes?: string
  next_maintenance_due?: string | null
}

export type AssignVehicleInput = {
  vehicle_id: string
  driver_id: string
  effective_from?: string
  effective_to?: string | null
  notes?: string
}

export type MaintenanceLogInput = {
  maintenance_type: MaintenanceType
  description: string
  cost?: number | null
  odometer_km?: number | null
  performed_at?: string
  next_due_date?: string | null
}
