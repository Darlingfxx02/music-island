import { describe, expect, it } from 'vitest'
import { getCloudGeometry, getCloudPixelRatio } from './cloudGeometry'

describe('cloud backing resolution', () => {
  it.each([
    [1, 1, 1], [1, 2, 2], [1, 3, 2],
    [2.8, 1, 2.8], [2.8, 2, 5.6], [1.9, 3, 3.8], [.65, 1, 1], [10, 2, 6],
  ])('preserves native density and resolves a %s× preview on a %s× display', (scale, devicePixelRatio, expected) => {
    expect(getCloudPixelRatio({ width: 132, height: 50,
      bounds: { width: 132 * scale, height: 50 * scale }, devicePixelRatio,
    })).toBeCloseTo(expected)
  })

  it('retains a safe native resolution before layout is available', () => {
    expect(getCloudPixelRatio({ width: 0, height: 0,
      bounds: { width: 0, height: 0 }, devicePixelRatio: 0,
    })).toBe(1)
  })
})

describe('cloud canvas coordinate space', () => {
  it.each([.65, 1, 1.9, 2.8])('keeps recorder and controls aligned at an outer CSS scale of %s', scale => {
    const geometry = getCloudGeometry({
      width: 132, height: 50, expanded: false,
      bounds: { left: 250, width: 132 * scale },
      coreBounds: { left: 250 + 4 * scale, width: 84 * scale },
    })
    expect(geometry.width).toBe(132)
    expect(geometry.height).toBe(50)
    expect(geometry.coreWidth).toBeCloseTo(84)
    expect(geometry.coreX).toBeCloseTo(46)
  })

  it('preserves the existing expanded text surface', () => {
    expect(getCloudGeometry({ width: 390, height: 82, expanded: true,
      bounds: { left: 20, width: 780 }, coreBounds: { left: 400, width: 168 },
    })).toEqual({ width: 390, height: 82, coreWidth: 382, coreX: 195 })
  })

  it('centers a standalone surface before the core ref is available', () => {
    expect(getCloudGeometry({ width: 92, height: 50, expanded: false,
      bounds: { left: 100, width: 92 },
    })).toEqual({ width: 92, height: 50, coreWidth: 84, coreX: 46 })
  })
})
