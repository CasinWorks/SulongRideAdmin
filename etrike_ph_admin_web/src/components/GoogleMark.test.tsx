import { describe, expect, it } from 'vitest'
import { render } from '@testing-library/react'
import { GoogleMark } from './GoogleMark'

describe('GoogleMark', () => {
  it('renders the Google SVG icon', () => {
    const { container } = render(<GoogleMark />)
    expect(container.querySelector('svg')).toBeTruthy()
    expect(container.querySelectorAll('path')).toHaveLength(4)
  })
})
