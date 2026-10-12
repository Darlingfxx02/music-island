// @vitest-environment happy-dom
import { act } from 'react'
import { createRoot } from 'react-dom/client'
import { expect, it, vi } from 'vitest'
import * as api from '../tauriApi'
import { useAppConfig } from './useAppConfig'
vi.mock('../tauriApi', async importOriginal => ({ ...await importOriginal<typeof api>(), getConfig: vi.fn(), onConfigChanged: vi.fn(), onAutostartSync: vi.fn().mockResolvedValue(() => {}) }))
it('keeps a change event newer than the pending initial read and disposes the listener', async () => {
  vi.stubGlobal('IS_REACT_ACT_ENVIRONMENT', true)
  const old = api.getDefaultConfig()
  const changed = { ...old, appearance: { ...old.appearance, accentColor: '#abcdef' } }
  let resolve!: (value: typeof old) => void
  vi.mocked(api.getConfig).mockReturnValue(new Promise(r => { resolve = r }))
  const dispose = vi.fn()
  vi.mocked(api.onConfigChanged).mockResolvedValue(dispose)
  let state!: ReturnType<typeof useAppConfig>
  function Probe() { state = useAppConfig(false); return null }
  const host = document.createElement('div'); const root = createRoot(host)
  try {
    await act(async () => root.render(<Probe />))
    await act(async () => vi.mocked(api.onConfigChanged).mock.calls[0][0](changed))
    await act(async () => resolve(old))
    expect(state.config.appearance.accentColor).toBe('#abcdef')
    expect(state.configLoaded).toBe(true)
    await act(async () => root.unmount())
    expect(dispose).toHaveBeenCalledOnce()
  } finally { await act(async () => root.unmount()); vi.unstubAllGlobals(); vi.resetAllMocks() }
})
