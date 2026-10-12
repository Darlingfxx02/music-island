// @vitest-environment happy-dom
import { act } from 'react'
import { createRoot } from 'react-dom/client'
import { expect, it, vi } from 'vitest'
import { useDictationMotion } from './useDictationMotion'

it('preserves the clock across speech, recognition and a paused result, and cancels inactive frames', async () => {
  Object.assign(globalThis, { IS_REACT_ACT_ENVIRONMENT: true })
  let tick: FrameRequestCallback = () => {}
  const raf = vi.spyOn(globalThis, 'requestAnimationFrame').mockImplementation(callback => { tick = callback; return 42 })
  const cancel = vi.spyOn(globalThis, 'cancelAnimationFrame')
  const container = document.createElement('div'), root = createRoot(container)
  function Probe({ demo, active = true }: { demo: boolean; active?: boolean }) {
    const frame = useDictationMotion(active, false, 0, demo)
    return <output data-time={frame.time} />
  }
  const time = () => Number(container.querySelector('output')?.getAttribute('data-time'))
  try {
    await act(async () => root.render(<Probe demo />))
    for (const at of [100, 150, 200, 250]) await act(async () => tick(at))
    expect(time()).toBeCloseTo(.15)
    await act(async () => root.render(<Probe demo={false} />))
    await act(async () => tick(300))
    expect(time()).toBeCloseTo(.2)
    await act(async () => root.render(<Probe demo={false} active={false} />))
    expect(time()).toBeCloseTo(.2)
    expect(cancel).toHaveBeenCalledWith(42)
    await act(async () => root.render(<Probe demo />))
    await act(async () => tick(1000))
    await act(async () => tick(1050))
    expect(time()).toBeCloseTo(.25)
  } finally { await act(async () => root.unmount()); raf.mockRestore(); cancel.mockRestore(); container.remove() }
})
