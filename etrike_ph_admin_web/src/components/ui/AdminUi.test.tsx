import { describe, expect, it, vi, beforeEach } from 'vitest'
import { render, screen } from '@testing-library/react'
import {
  DividerList,
  ErrorState,
  GhostButton,
  LoadingState,
  PanelCard,
  PrimaryButton,
  ReviewListRow,
  ScreenLoader,
  StatCard,
  StatusPill,
} from './AdminUi'

describe('AdminUi', () => {
  it('renders StatCard', () => {
    render(<StatCard label="Trips" value="12" hint="Yesterday: 8" index={1} />)
    expect(screen.getByText('Trips')).toBeInTheDocument()
    expect(screen.getByText('12')).toBeInTheDocument()
    expect(screen.getByText('Yesterday: 8')).toBeInTheDocument()
  })

  it('renders PanelCard with action', () => {
    render(
      <PanelCard title="Drivers" action={<button type="button">Filter</button>} index={2}>
        <p>Panel body</p>
      </PanelCard>,
    )
    expect(screen.getByText('Drivers')).toBeInTheDocument()
    expect(screen.getByText('Panel body')).toBeInTheDocument()
    expect(screen.getByText('Filter')).toBeInTheDocument()
  })

  it('renders StatusPill variants', () => {
    const { rerender } = render(<StatusPill status="approved" />)
    expect(screen.getByText('approved')).toBeInTheDocument()
    rerender(<StatusPill status="super_admin" />)
    expect(screen.getByText('super admin')).toBeInTheDocument()
    rerender(<StatusPill status="rejected" />)
    expect(screen.getByText('rejected')).toBeInTheDocument()
  })

  it('renders buttons', () => {
    const onClick = vi.fn()
    render(
      <>
        <PrimaryButton onClick={onClick}>Save</PrimaryButton>
        <GhostButton onClick={onClick}>Cancel</GhostButton>
      </>,
    )
    screen.getByText('Save').click()
    screen.getByText('Cancel').click()
    expect(onClick).toHaveBeenCalledTimes(2)
  })

  it('renders loading and error states', () => {
    render(<LoadingState label="Please wait" />)
    expect(screen.getByText('Please wait')).toBeInTheDocument()
    render(<ErrorState message="Something failed" />)
    expect(screen.getByText('Something failed')).toBeInTheDocument()
  })

  it('renders screen loader', () => {
    render(<ScreenLoader />)
    expect(screen.getByText('Loading…')).toBeInTheDocument()
  })

  it('renders review list layout', () => {
    render(
      <DividerList>
        <ReviewListRow actions={<button type="button">Go</button>}>
          <span>Row content</span>
        </ReviewListRow>
      </DividerList>,
    )
    expect(screen.getByText('Row content')).toBeInTheDocument()
    expect(screen.getByText('Go')).toBeInTheDocument()
  })
})

describe('adminPageUi barrel', () => {
  beforeEach(async () => {
    const mod = await import('./adminPageUi')
    expect(mod.ScreenLoader).toBeDefined()
    expect(mod.adminInputCls).toContain('rounded-xl')
  })

  it('re-exports shared page components', () => {
    expect(true).toBe(true)
  })
})
