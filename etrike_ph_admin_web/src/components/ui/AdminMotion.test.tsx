import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { BirthdayNotice, FadeIn, PageTransition, staggerStyle } from './AdminMotion'

describe('AdminMotion', () => {
  it('computes stagger style', () => {
    expect(staggerStyle(0)).toEqual({ animationDelay: '0ms' })
    expect(staggerStyle(10)).toEqual({ animationDelay: '330ms' })
  })

  it('renders fade and page transition wrappers', () => {
    const { container: fade } = render(<FadeIn index={2}>Content</FadeIn>)
    expect(fade.textContent).toContain('Content')
    const { container: page } = render(<PageTransition>Page</PageTransition>)
    expect(page.querySelector('.admin-page-enter')).toBeTruthy()
  })

  it('renders birthday notice with link for one person', () => {
    render(
      <MemoryRouter>
        <BirthdayNotice people={[{ id: 'd1', name: 'Ana' }]} />
      </MemoryRouter>,
    )
    expect(screen.getByText(/Ana has a birthday today/)).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'View profile' })).toHaveAttribute('href', '/drivers/d1')
  })

  it('returns null when no birthdays', () => {
    const { container } = render(<BirthdayNotice people={[]} />)
    expect(container.firstChild).toBeNull()
  })

  it('shows message for two birthdays', () => {
    render(
      <MemoryRouter>
        <BirthdayNotice
          people={[
            { id: 'd1', name: 'Ana' },
            { id: 'd2', name: 'Ben' },
          ]}
        />
      </MemoryRouter>,
    )
    expect(screen.getByText(/Ana and Ben have birthdays today/)).toBeInTheDocument()
  })

  it('shows message for many birthdays', () => {
    render(
      <MemoryRouter>
        <BirthdayNotice
          people={[
            { id: 'd1', name: 'Ana' },
            { id: 'd2', name: 'Ben' },
            { id: 'd3', name: 'Cal' },
          ]}
        />
      </MemoryRouter>,
    )
    expect(screen.getByText(/and 1 more have birthdays today/)).toBeInTheDocument()
  })
})
