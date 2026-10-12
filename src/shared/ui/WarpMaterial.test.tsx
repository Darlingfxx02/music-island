// @vitest-environment happy-dom
import { act } from 'react'
import { createRoot } from 'react-dom/client'
import { expect, it, vi } from 'vitest'
import { WarpMaterial } from './WarpMaterial'
import { StatefulWarpSurface } from './StatefulWarpSurface'
import { WarpSurfaceProvider } from './WarpSurface'
vi.mock('framer-motion', () => ({ useReducedMotion: () => false }))
vi.mock('@paper-design/shaders-react', () => ({ Warp: ({ speed, frame, colors }: { speed: number; frame?: number; colors: string[] }) => <canvas data-speed={speed} data-frame={frame} data-colors={colors.join(',')} /> }))

it('uses the release dictation palette in both material variants', async () => {
  Object.assign(globalThis, { IS_REACT_ACT_ENVIRONMENT: true })
  const host = document.createElement('div'); document.body.append(host)
  const root = createRoot(host)
  try {
    for (const variant of ['default', 'onboarding'] as const) {
      await act(async () => root.render(<WarpMaterial variant={variant} />))
      expect(host.querySelector('canvas')?.dataset.colors).toBe('#231c2c,#ad867e,#ebc8a6,#c4adf0')
    }
  } finally { await act(async () => root.unmount()); host.remove() }
})

it.each([false, true])('halves the enable speed increase without replacing the canvas (shared: %s)', async (shared) => {
  Object.assign(globalThis, { IS_REACT_ACT_ENVIRONMENT: true })
  const host = document.createElement('div'); document.body.append(host)
  const root = createRoot(host)
  const view = (running: boolean, reducedMotion = false) => {
    const field = <StatefulWarpSurface running={running} reducedMotion={reducedMotion} />
    return shared ? <WarpSurfaceProvider>{field}</WarpSurfaceProvider> : field
  }
  try {
    await act(async () => root.render(view(false)))
    const canvas = host.querySelector('canvas')!
    expect(canvas.dataset.speed).toBe('0.225')
    await act(async () => root.render(view(true)))
    expect(canvas.dataset.speed).toBe('1.1625')
    expect(host.querySelector('[data-running]')?.getAttribute('data-running')).toBe('true')
    await act(async () => root.render(view(true, true)))
    expect(canvas.dataset.speed).toBe('0')
    await act(async () => root.render(view(false)))
    expect(canvas.dataset.speed).toBe('0.225')
    expect(host.querySelector('canvas')).toBe(canvas)
  } finally { await act(async () => root.unmount()); host.remove() }
})

it('pauses inactive, hidden and reduced-motion renderers without dropping the canvas', async () => {
  Object.assign(globalThis, { IS_REACT_ACT_ENVIRONMENT: true })
  const host = document.createElement('div'); document.body.append(host)
  const root = createRoot(host)
  try {
    await act(async () => root.render(<WarpMaterial speed={2.1} />))
    const canvas = host.querySelector('canvas')!
    expect(canvas.dataset.speed).toBe('2.1')
    await act(async () => root.render(<WarpMaterial active={false} />))
    expect(host.querySelector('canvas')).toBe(canvas); expect(canvas.dataset.speed).toBe('0')
    await act(async () => root.render(<WarpMaterial reducedMotion />))
    expect(canvas.dataset.speed).toBe('0')
    await act(async () => root.render(<WarpMaterial />))
    expect(canvas.dataset.speed).toBe('0.225')
    vi.spyOn(document, 'visibilityState', 'get').mockReturnValue('hidden')
    await act(async () => document.dispatchEvent(new Event('visibilitychange')))
    expect(canvas.dataset.speed).toBe('0')
    await act(async () => root.render(<WarpMaterial frame={1234} />))
    expect(canvas.dataset.frame).toBe('1234'); expect(host.querySelector('canvas')).toBe(canvas)
  } finally { await act(async () => root.unmount()); host.remove(); vi.restoreAllMocks() }
})

it('prewarms deferred fields only near the viewport and retains the same canvas on revisit', async () => {
  Object.assign(globalThis, { IS_REACT_ACT_ENVIRONMENT: true })
  const observers: { callback: IntersectionObserverCallback; margin?: string }[] = []
  vi.stubGlobal('IntersectionObserver', class {
    constructor(callback: IntersectionObserverCallback, options?: IntersectionObserverInit) { observers.push({ callback, margin: options?.rootMargin }) }
    observe() {} disconnect() {}
  })
  const host = document.createElement('div'); document.body.append(host)
  const root = createRoot(host)
  const intersect = (observer: typeof observers[number], value: boolean) => observer.callback([{ isIntersecting: value } as IntersectionObserverEntry], {} as IntersectionObserver)
  try {
    await act(async () => root.render(<WarpMaterial deferUntilNearViewport speed={2.1} />))
    expect(host.querySelector('canvas')).toBeNull()
    const preparation = observers.find(observer => observer.margin === '600px')!
    const visibility = observers.find(observer => !observer.margin)!
    await act(async () => { intersect(visibility, false); intersect(preparation, true) })
    const canvas = host.querySelector('canvas')!
    expect(canvas.dataset.speed).toBe('0')
    await act(async () => intersect(visibility, true))
    expect(canvas.dataset.speed).toBe('2.1')
    await act(async () => intersect(visibility, false))
    await act(async () => root.render(<WarpMaterial deferUntilNearViewport speed={2.1} />))
    await act(async () => intersect(visibility, true))
    expect(host.querySelector('canvas')).toBe(canvas)
    expect(canvas.dataset.speed).toBe('2.1')
  } finally { await act(async () => root.unmount()); host.remove(); vi.unstubAllGlobals() }
})

it('renders deterministic deferred exports immediately', async () => {
  const host = document.createElement('div'); document.body.append(host)
  const root = createRoot(host)
  try {
    await act(async () => root.render(<WarpMaterial deferUntilNearViewport frame={4200} />))
    expect(host.querySelector('canvas')?.dataset.frame).toBe('4200')
  } finally { await act(async () => root.unmount()); host.remove() }
})
