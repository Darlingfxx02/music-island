// @vitest-environment happy-dom
import { act } from 'react'
import { createRoot, type Root } from 'react-dom/client'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { VoiceFoxVideoMascot } from './VoiceFoxVideoMascot'
let root: Root
let host: HTMLDivElement
beforeEach(() => {
  vi.useFakeTimers()
  vi.stubGlobal('IS_REACT_ACT_ENVIRONMENT', true)
  vi.spyOn(HTMLMediaElement.prototype, 'play').mockResolvedValue()
  vi.spyOn(HTMLMediaElement.prototype, 'pause').mockImplementation(() => {})
  host = document.createElement('div'); document.body.append(host); root = createRoot(host)
})
afterEach(async () => {
  await act(async () => root.unmount())
  host.remove(); vi.useRealTimers(); vi.restoreAllMocks(); vi.unstubAllGlobals()
})
async function startTransition() {
  await act(async () => root.render(<VoiceFoxVideoMascot live={false} />))
  await act(async () => root.render(<VoiceFoxVideoMascot live />))
  expect(vi.getTimerCount()).toBe(1)
  return host.querySelectorAll('video')
}
it('cancels pending clip waits when the component unmounts', async () => {
  await startTransition()
  await act(async () => root.unmount())
  await act(async () => vi.advanceTimersByTime(50))
  expect(vi.getTimerCount()).toBe(0)
})
it('recovers from decode failure without cutting a healthy clip short', async () => {
  const videos = await startTransition()
  expect(videos[1].className).not.toContain('active')
  await act(async () => videos[0].dispatchEvent(new Event('error')))
  expect(videos[1].className).toContain('active')
  await act(async () => videos[1].dispatchEvent(new Event('error')))
  expect(videos[2].className).toContain('active')
  expect(vi.getTimerCount()).toBe(0)
})
it('lets healthy sleep and wake clips end before showing the live loop', async () => {
  const videos = await startTransition()
  await act(async () => vi.advanceTimersByTime(250))
  expect(videos[0].className).toContain('active')
  await act(async () => videos[0].dispatchEvent(new Event('ended')))
  expect(videos[1].className).toContain('active')
  expect(videos[2].className).not.toContain('active')
  await act(async () => videos[1].dispatchEvent(new Event('ended')))
  expect(videos[2].className).toContain('active')
  expect(vi.getTimerCount()).toBe(0)
})
it('continues the live pack after Stop and Start before the current clip ends', async () => {
  await act(async () => root.render(<VoiceFoxVideoMascot live />))
  const live = host.querySelectorAll('video')[2]
  const source = live.getAttribute('src')
  await act(async () => root.render(<VoiceFoxVideoMascot live={false} />))
  await act(async () => root.render(<VoiceFoxVideoMascot live />))
  await act(async () => vi.advanceTimersByTime(50))
  await act(async () => live.dispatchEvent(new Event('ended')))
  expect(live.getAttribute('src')).not.toBe(source)
  expect(live.className).toContain('active')
})
it('finishes wake after reversing Stop back to Start during that clip', async () => {
  const videos = await startTransition()
  await act(async () => videos[0].dispatchEvent(new Event('ended')))
  expect(videos[1].className).toContain('active')
  await act(async () => root.render(<VoiceFoxVideoMascot live={false} />))
  await act(async () => root.render(<VoiceFoxVideoMascot live />))
  await act(async () => vi.advanceTimersByTime(50))
  await act(async () => videos[1].dispatchEvent(new Event('ended')))
  expect(videos[2].className).toContain('active')
})
it('finishes falling asleep after reversing Start back to Stop during that clip', async () => {
  await act(async () => root.render(<VoiceFoxVideoMascot live />))
  const videos = host.querySelectorAll('video')
  await act(async () => root.render(<VoiceFoxVideoMascot live={false} />))
  await act(async () => videos[2].dispatchEvent(new Event('ended')))
  expect(videos[3].className).toContain('active')
  await act(async () => root.render(<VoiceFoxVideoMascot live />))
  await act(async () => root.render(<VoiceFoxVideoMascot live={false} />))
  await act(async () => vi.advanceTimersByTime(50))
  await act(async () => videos[3].dispatchEvent(new Event('ended')))
  expect(videos[0].className).toContain('active')
})
it('restarts a live clip that ended while a cancelled chain was settling', async () => {
  await act(async () => root.render(<VoiceFoxVideoMascot live />))
  const live = host.querySelectorAll('video')[2]
  const source = live.getAttribute('src')
  await act(async () => root.render(<VoiceFoxVideoMascot live={false} />))
  await act(async () => root.render(<VoiceFoxVideoMascot live />))
  await act(async () => {
    Object.defineProperty(live, 'ended', { configurable: true, get: () => true })
    live.dispatchEvent(new Event('ended'))
  })
  await act(async () => vi.advanceTimersByTime(50))
  expect(live.getAttribute('src')).not.toBe(source)
})
