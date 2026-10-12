import { useId } from 'react'
import './ColorSwatches.css'

export type ColorSwatchOption<T extends string> = { value: T; label: string; color: string }

/** Native radio behavior with the settings DS focus ring, spacing and type. */
export function ColorSwatches<T extends string>({ value, options, onChange, ariaLabel }: {
  value: T; options: readonly ColorSwatchOption<T>[]; onChange: (value: T) => void; ariaLabel: string
}) {
  const id = useId()
  return <div className="ui-color-swatches" role="radiogroup" aria-label={ariaLabel}>
    {options.map(option => <label className="ui-color-swatch" key={option.value} data-selected={option.value === value}>
      <input type="radio" name={id} value={option.value} checked={option.value === value} onChange={() => onChange(option.value)} />
      <span className="ui-color-swatch__color" style={{ background: option.color }} aria-hidden="true" />
      <span className="ui-color-swatch__label">{option.label}</span>
    </label>)}
  </div>
}
