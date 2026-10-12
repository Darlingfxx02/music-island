import { useState, type ComponentProps } from 'react'
import type { Meta, StoryObj } from '@storybook/react-vite'
import { fn } from 'storybook/test'
import { ColorSwatches } from '../../shared/ui/ColorSwatches'
const options = [
  { value: 'white', label: 'Белый', color: '#ffffff' },
  { value: 'blue', label: 'Синий', color: '#3987e8' },
  { value: 'cyan', label: 'Бирюзовый', color: '#36aeb7' },
  { value: 'rose', label: 'Розовый', color: '#d36d99' },
  { value: 'amber', label: 'Янтарный', color: '#c89442' },
]
function SwatchesDemo({ args, light = false }: { args: ComponentProps<typeof ColorSwatches>; light?: boolean }) {
  const [value, setValue] = useState(args.value)
  return <div className="settings-panel" data-color-scheme={light ? 'light' : 'dark'} style={{ padding: 24, background: 'var(--surface-panel)', borderRadius: 16 }}><ColorSwatches {...args} value={value} onChange={next => { setValue(next); args.onChange(next) }} /></div>
}
const meta = { title: 'Atoms/ColorSwatches', component: ColorSwatches, args: { value: 'blue', options, ariaLabel: 'Цвет', onChange: fn<(value: string) => void>() }, parameters: { workshop: { width: 420 } }, render: (args, context) => <SwatchesDemo key={args.value} args={args} light={Boolean(context.parameters.light)} /> } satisfies Meta<typeof ColorSwatches>
export default meta
type Story = StoryObj<typeof meta>
export const Default: Story = { name: 'Цвета · тёмная тема' }
export const Light: Story = { name: 'Цвета · светлая тема', parameters: { light: true } }
