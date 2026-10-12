import { renderToStaticMarkup } from 'react-dom/server'
import { expect, it } from 'vitest'
import { DictationVisual } from './DictationVisual'
import { defaultDictationAppearance } from '../../shared/lib/dictationAppearance'
const appearance = { ...defaultDictationAppearance, theme: 'pixels' as const }
it('keeps fox ears on the character and removes them from games and delivery indicators', () => {
  const markup = (phase: string) => renderToStaticMarkup(<DictationVisual appearance={appearance} phase={phase} levels={[]} still />)
  expect(markup('recording')).toContain('dictation-pixel-ears')
  expect(markup('preparing')).toContain('dictation-pixel-ears')
  for (const phase of ['transcribing','processing','completed','error','cancelled']) {
    expect(markup(phase)).not.toContain('dictation-pixel-ears')
  }
  expect(markup('transcribing')).toContain('data-game=')
  expect(markup('recording')).toContain('data-character="fox"')
})

