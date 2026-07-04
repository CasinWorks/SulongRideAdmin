export type TrainingStatus = 'not_started' | 'in_progress' | 'completed'

export type TrainingMode = 'online' | 'onsite'

export type DriverTrainingRow = {
  driver_id: string
  status: TrainingStatus
  mode: TrainingMode
  started_at: string | null
  completed_at: string | null
  completed_by: string | null
  quiz_passed_at: string | null
  quiz_score: number | null
  admin_notes: string | null
  created_at: string
  updated_at: string
}

export type DriverTrainingWithProfile = DriverTrainingRow & {
  full_name: string
  email: string
  approval_status: string
}
