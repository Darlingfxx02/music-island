import { expect, it } from 'vitest'
import { DictationSpring } from './dictationSpring'

it('matches the reference response independently of frame rate and retains motion on reversal', () => {
  const once = new DictationSpring(0, .314), frames = new DictationSpring(0, .314)
  const target = once.step(1, .1)
  for (let i = 0; i < 6; i++) frames.step(1, .1 / 6)
  expect(frames.value).toBeCloseTo(target, 12)
  expect(target).toBeGreaterThan(.5)
  expect(target).toBeLessThan(1)
  // An interrupted arrival continues with its existing velocity, without a jump.
  expect(frames.step(0, .001)).toBeGreaterThan(target)
  expect(frames.step(0, .5)).toBeLessThan(.01)
  expect(frames.step(1, 0, true)).toBe(1)
  expect(frames.step(1, .1)).toBe(1)
})
