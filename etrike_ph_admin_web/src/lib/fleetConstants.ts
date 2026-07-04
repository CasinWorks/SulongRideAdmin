import type { AssignmentStatus, MaintenanceType, VehicleStatus } from '../types/fleet'

export const VEHICLE_STATUS_LABELS: Record<VehicleStatus, string> = {
  available: 'Available',
  assigned: 'Assigned',
  maintenance: 'In maintenance',
  retired: 'Retired',
}

export const ASSIGNMENT_STATUS_LABELS: Record<AssignmentStatus, string> = {
  scheduled: 'Scheduled',
  active: 'Active',
  ended: 'Ended',
  cancelled: 'Cancelled',
}

export const MAINTENANCE_TYPE_LABELS: Record<MaintenanceType, string> = {
  general: 'General service',
  battery: 'Battery',
  tires: 'Tires',
  brakes: 'Brakes',
  electrical: 'Electrical',
  body: 'Body / panels',
  inspection: 'Inspection',
}

export function vehicleStatusClass(status: VehicleStatus): string {
  switch (status) {
    case 'available':
      return 'bg-green-100 text-green-800'
    case 'assigned':
      return 'bg-sky-100 text-sky-900'
    case 'maintenance':
      return 'bg-amber-100 text-amber-900'
    default:
      return 'bg-black/8 text-black/50'
  }
}
