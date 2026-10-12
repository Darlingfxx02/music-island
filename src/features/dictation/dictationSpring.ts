/** The reference recorder's critically damped spring (response in seconds).
 * Analytical integration preserves velocity through interruptions at any FPS. */
export class DictationSpring {
  value: number
  private velocity = 0
  private response: number
  constructor(value: number, response: number) { this.value = value; this.response = response }
  step(target: number, delta: number, instant = false) {
    if (instant) { this.value = target; this.velocity = 0; return this.value }
    const omega = Math.PI * 2 / this.response
    const offset = this.value - target, impulse = this.velocity + omega * offset
    const dt = Math.max(0, delta), decay = Math.exp(-omega * dt)
    this.value = target + (offset + impulse * dt) * decay
    this.velocity = (this.velocity - omega * impulse * dt) * decay
    return this.value
  }
}
