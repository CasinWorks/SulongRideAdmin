import { describe, expect, it, vi, beforeEach } from 'vitest'
import { fetchTodaysBirthdays, isBirthdayToday } from './birthdays'

vi.mock('./supabase', () => ({
  supabase: {
    from: vi.fn(),
  },
}))

import { supabase } from './supabase'

describe('isBirthdayToday', () => {
  it('returns false for missing date', () => {
    expect(isBirthdayToday(null)).toBe(false)
    expect(isBirthdayToday(undefined)).toBe(false)
  })

  it('matches month and day in local timezone', () => {
    const now = new Date()
    const iso = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
    expect(isBirthdayToday(iso)).toBe(true)
  })

  it('returns false for invalid date', () => {
    expect(isBirthdayToday('not-a-date')).toBe(false)
  })
})

describe('fetchTodaysBirthdays', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('returns birthday people from approved drivers', async () => {
    const now = new Date()
    const iso = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
    vi.mocked(supabase.from).mockReturnValue({
      select: vi.fn().mockReturnValue({
        eq: vi.fn().mockResolvedValue({
          data: [
            {
              id: 'd1',
              full_name: 'Ana',
              email: 'ana@example.com',
              date_of_birth: iso,
              approval_status: 'approved',
            },
          ],
          error: null,
        }),
      }),
    } as never)

    const people = await fetchTodaysBirthdays()
    expect(people).toEqual([{ id: 'd1', name: 'Ana' }])
  })

  it('returns empty list when date_of_birth column is missing', async () => {
    vi.mocked(supabase.from).mockReturnValue({
      select: vi.fn().mockReturnValue({
        eq: vi.fn().mockResolvedValue({
          data: null,
          error: { code: '42703', message: 'date_of_birth missing' },
        }),
      }),
    } as never)

    await expect(fetchTodaysBirthdays()).resolves.toEqual([])
  })
})
