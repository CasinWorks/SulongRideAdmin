import { supabase } from './supabase'
import { driverDisplayName } from './format'

/** Month/day match in local timezone (ignores birth year). */
export function isBirthdayToday(iso: string | null | undefined): boolean {
  if (!iso) return false
  const dob = new Date(iso.includes('T') ? iso : `${iso}T12:00:00`)
  if (Number.isNaN(dob.getTime())) return false
  const now = new Date()
  return dob.getMonth() === now.getMonth() && dob.getDate() === now.getDate()
}

export type BirthdayPerson = {
  id: string
  name: string
}

/** Approved drivers with `date_of_birth` set to today. Returns [] if column is missing. */
export async function fetchTodaysBirthdays(): Promise<BirthdayPerson[]> {
  const { data, error } = await supabase
    .from('drivers')
    .select('id, full_name, email, date_of_birth, approval_status')
    .eq('approval_status', 'approved')

  if (error) {
    // `date_of_birth` may not exist on older schemas — fail quietly.
    if (error.message.includes('date_of_birth') || error.code === '42703') return []
    throw error
  }

  return (data ?? [])
    .filter((row) => isBirthdayToday(row.date_of_birth as string | null))
    .map((row) => ({
      id: row.id as string,
      name: driverDisplayName({
        full_name: row.full_name as string,
        email: row.email as string,
      }),
    }))
}
