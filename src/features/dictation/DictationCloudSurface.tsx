import { useEffect, useRef, useState, type RefObject } from 'react'
import { DictationCloudRenderer, type CloudFrame } from './DictationCloudRenderer'
import type { DictationAppearance } from '../../shared/lib/dictationAppearance'
import { getCloudGeometry } from './cloudGeometry'

export function DictationCloudSurface({ appearance, phase, levels, still = false, active = true, demo = false, coreRef, expanded = false, singleControl = false }: {
  appearance: DictationAppearance; phase: string; levels: number[]; still?: boolean; active?: boolean; demo?: boolean
  coreRef?: RefObject<HTMLElement | null>; expanded?: boolean; singleControl?: boolean
}) {
  const canvas = useRef<HTMLCanvasElement>(null)
  const input = useRef({ appearance, phase, levels, demo, coreRef, expanded, singleControl })
  input.current = { appearance, phase, levels, demo, coreRef, expanded, singleControl }
  const redraw = useRef<(() => void) | null>(null)
  const [failed, setFailed] = useState(false)
  useEffect(() => {
    const surface = canvas.current
    if (!surface) return
    let renderer: DictationCloudRenderer | null = null
    let raf = 0, last = 0, time = 0, envelope = 0
    const paint = (delta: number) => {
      if (!renderer) return
      const next = input.current, recording = ['recording','streaming'].includes(next.phase)
      const peak = Math.max(0,...next.levels.filter(Number.isFinite))
      const sample = next.demo && recording ? Math.sin(time*2.4)>-.25 ? .25+.55*Math.abs(Math.sin(time*4.1)) : 0 : recording ? peak : 0
      const target = Math.max(0,Math.min(1,sample))
      envelope = still || !delta ? target : envelope+(target-envelope)*(1-Math.exp(-delta/(target>envelope?.025:.12)))
      const bounds = surface.getBoundingClientRect(), coreBounds = next.coreRef?.current?.getBoundingClientRect()
      const { width, height, coreWidth, coreX } = getCloudGeometry({
        width: surface.clientWidth, height: surface.clientHeight, bounds, coreBounds, expanded: next.expanded,
      })
      const controls = !next.expanded && next.coreRef ? Math.max(0,Math.min(1,(width-92)/(next.singleControl ? 40 : 80))) : 0
      const accent = getComputedStyle(surface).getPropertyValue('--accent').trim()
      const match = accent.match(/^#([\da-f]{6})$/i)
      const color = match ? [0,2,4].map(at=>parseInt(match[1].slice(at,at+2),16)/255) : [94/255,106/255,210/255]
      const frame: CloudFrame = { time: still ? 0 : time, delta, level: envelope, phase: next.phase, instant: still || !active,
        appearance: next.appearance, controls, coreWidth, coreX, singleControl: next.singleControl, coreHeight: next.expanded ? height-6 : 44,
        coreY: next.expanded ? height/2 : height-25, accent: color }
      try { renderer.render(frame) } catch { setFailed(true); cancelAnimationFrame(raf); renderer.dispose(); renderer=null }
    }
    const tick = (now: number) => {
      const delta = last ? Math.min(.1,(now-last)/1000) : 0
      last=now; time+=delta; paint(delta)
      if (renderer) raf=requestAnimationFrame(tick)
    }
    const update = () => {
      cancelAnimationFrame(raf); last=0
      if (document.visibilityState !== 'visible') return
      paint(0)
      if (active && !still && renderer) raf=requestAnimationFrame(tick)
    }
    const initialize = () => {
      try { renderer=new DictationCloudRenderer(surface); setFailed(false); update() }
      catch { setFailed(true) }
    }
    const lost = (event: Event) => { event.preventDefault(); cancelAnimationFrame(raf); renderer?.dispose(); renderer=null; setFailed(true) }
    const restored = () => initialize()
    initialize()
    redraw.current = () => { if ((!active || still) && document.visibilityState === 'visible') paint(0) }
    document.addEventListener('visibilitychange',update)
    surface.addEventListener('webglcontextlost',lost)
    surface.addEventListener('webglcontextrestored',restored)
    return () => {
      cancelAnimationFrame(raf); redraw.current=null; renderer?.dispose()
      document.removeEventListener('visibilitychange',update)
      surface.removeEventListener('webglcontextlost',lost);surface.removeEventListener('webglcontextrestored',restored)
    }
  }, [active,still])
  useEffect(() => { redraw.current?.() }, [appearance,phase,levels,expanded,singleControl])
  return <canvas ref={canvas} className={'dictation-cloud-surface'+(appearance.theme==='wave'?' dictation-visual--wave':'')} data-fallback={failed || undefined} aria-hidden="true" />
}

