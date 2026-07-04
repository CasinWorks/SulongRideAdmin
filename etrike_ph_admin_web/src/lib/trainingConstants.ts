import type { TrainingMode, TrainingStatus } from '../types/training'

export const TRAINING_STATUS_LABELS: Record<TrainingStatus, string> = {
  not_started: 'Not started',
  in_progress: 'In progress',
  completed: 'Completed',
}

export const TRAINING_MODE_LABELS: Record<TrainingMode, string> = {
  online: 'Online module',
  onsite: 'Onsite session',
}

export function trainingStatusClass(status: TrainingStatus): string {
  switch (status) {
    case 'completed':
      return 'bg-green-100 text-green-800'
    case 'in_progress':
      return 'bg-sky-100 text-sky-900'
    default:
      return 'bg-black/8 text-black/50'
  }
}
