import type { Meta, StoryObj } from '@storybook/react-vite'
import { expect, fn, userEvent, within } from 'storybook/test'
import { DictationOverlayView } from '../../features/dictation/DictationOverlay'
import { defaultDictationAppearance } from '../../shared/lib/dictationAppearance'
const meta = { title: 'Molecules/DictationOverlay', component: DictationOverlayView,
  args: { visible: true, status: {revision: 1, operationId: 1, phase: 'recording', ready: true, text: '', error: null}, levels: [.3,.5,.7,.9,.4,.6,.3,.2], text: {committed: '', tentative: ''}, locale: 'ru', finish: fn(async () => {}), cancel: fn(async () => {}), copy: fn(async () => {}) },
  parameters: {workshop: {width: 550, height: 200}},
} satisfies Meta<typeof DictationOverlayView>
export default meta
type Story = StoryObj<typeof meta>
export const Recording: Story = {name: 'Запись'}
export const Preparing: Story = {name: 'Подготовка', args: {status: {...meta.args.status, phase: 'preparing', ready: false}}}
export const Transcribing: Story = {name: 'Распознавание', args: {status: {...meta.args.status, phase: 'transcribing'}}}
export const Processing: Story = {name: 'Обработка текста', args: {status: {...meta.args.status, phase: 'processing'}}}
export const Completed: Story = {name: 'Готово', args: {status: {...meta.args.status, phase: 'completed', text: 'Тестовая запись.'}}}
export const Cancelled: Story = {name: 'Отменено', args: {status: {...meta.args.status, phase: 'cancelled'}}}
export const Error: Story = {name: 'Ошибка вставки · копирование', args: {status: {...meta.args.status, phase: 'error', text: 'Тестовая запись.', error: 'Target window closed'}}, play: async ({ canvasElement, args }) => {
  await userEvent.click(within(canvasElement).getByRole('button', { name: 'Скопировать текст' }))
  await expect(args.copy).toHaveBeenCalledOnce()
}}
export const LiveText: Story = {name: 'Потоковый текст', args: {text: {committed: 'Отправьте, пожалуйста, ', tentative: 'последнюю версию'}}}
export const ReducedMotion: Story = {name: 'Без движения · English', args: {reducedMotion: true, locale: 'en'}}
export const Waves: Story = { name: 'Волны · запись', args: { appearance: { ...defaultDictationAppearance, theme: 'wave', palette: 'prism' }, demo: true } }
export const WaveProcessing: Story = { ...Waves, name: 'Волны · светящиеся частицы при распознавании', args: { ...Waves.args, status: { ...meta.args.status, phase: 'transcribing' } } }
export const WaveCompleted: Story = { ...Waves, name: 'Волны · частицы собираются в галочку', args: { ...Waves.args, status: { ...meta.args.status, phase: 'completed' } } }
export const WaveStill: Story = { ...Waves, name: 'Волны · без движения', args: { ...Waves.args, reducedMotion: true } }
export const CloudActions: Story = { ...Waves, name: 'Волны · одна кнопка завершения', play: async ({ canvasElement, args }) => {
  const canvas = within(canvasElement)
  await expect(canvas.queryByRole('button', { name: /^Отменить запись$/ })).not.toBeInTheDocument()
  await expect(canvas.queryAllByRole('button', { name: /Завершить/ })).toHaveLength(1)
  await userEvent.click(canvas.getByRole('button', { name: /^Завершить запись$/ }))
  await expect(args.finish).toHaveBeenCalledOnce()
  await expect(args.cancel).not.toHaveBeenCalled()
} }
export const WaveHold: Story = { ...Waves, name: 'Волны · удержание без кнопок', args: { ...Waves.args, status: { ...meta.args.status, shortcutActivation: 'push_to_talk' } }, play: async ({ canvasElement }) => {
  await expect(within(canvasElement).queryAllByRole('button')).toHaveLength(0)
} }
export const ClassicHold: Story = { name: 'Классическая · удержание без кнопок', args: { status: { ...meta.args.status, shortcutActivation: 'push_to_talk' } } }
export const SlowModelLoad: Story = { name: 'Холодный запуск · загрузка модели', args: { status: { ...meta.args.status, phase: 'transcribing', modelLoading: true } } }
export const SlowLiveModelLoad: Story = { ...Waves, name: 'Потоковая запись · долгая загрузка модели', args: { ...Waves.args, status: { ...meta.args.status, phase: 'streaming', modelLoading: true, shortcutActivation: 'push_to_talk' } } }
export const FoxQuiet: Story = { name: 'Лиса · тишина и глазки', args: { appearance: { ...defaultDictationAppearance, theme: 'pixels' }, levels: [] } }
export const PixelFox: Story = { name: 'Лиса · речь и ушки', args: { appearance: { ...defaultDictationAppearance, theme: 'pixels', palette: 'ember' }, demo: true } }
export const FoxHold: Story = { ...PixelFox, name: 'Лиса · удержание без кнопок', args: { ...PixelFox.args, status: { ...meta.args.status, shortcutActivation: 'push_to_talk' } }, play: WaveHold.play }
export const FoxSingleAction: Story = { ...PixelFox, name: 'Лиса · одна кнопка завершения', play: async ({ canvasElement, args }) => {
  const canvas = within(canvasElement)
  await expect(canvas.queryByRole('button', { name: 'Отменить запись' })).not.toBeInTheDocument()
  await expect(canvas.queryAllByRole('button', { name: /Завершить/ })).toHaveLength(1)
  await expect(canvasElement.querySelectorAll('.dictation-cloud__satellite')).toHaveLength(1)
  await userEvent.click(canvas.getByRole('button', { name: /^Завершить запись$/ }))
  await expect(args.finish).toHaveBeenCalledOnce()
  await expect(args.cancel).not.toHaveBeenCalled()
} }
export const FoxLiveText: Story = { ...PixelFox, name: 'Лиса · потоковый текст', args: { ...PixelFox.args, ...LiveText.args } }
export const FoxPreparing: Story = { ...PixelFox, name: 'Лиса · подготовка', args: { ...PixelFox.args, status: { ...meta.args.status, phase: 'preparing' } } }
export const FoxProcessing: Story = { ...PixelFox, name: 'Распознавание · мини-игры без ушек', args: { ...PixelFox.args, status: { ...meta.args.status, phase: 'transcribing' } } }
export const FoxSnake: Story = { ...FoxProcessing, name: 'Змейка · без ушек', args: { ...FoxProcessing.args, status: { ...meta.args.status, phase: 'transcribing', operationId: 2 }, reducedMotion: true } }
export const FoxCompleted: Story = { ...PixelFox, name: 'Лиса · готово', args: { ...PixelFox.args, status: { ...meta.args.status, phase: 'completed' } } }
export const FoxError: Story = { ...PixelFox, name: 'Лиса · ошибка вставки', args: { ...PixelFox.args, status: { ...meta.args.status, phase: 'error', text: 'Тестовая запись.' } } }
export const FoxStill: Story = { ...PixelFox, name: 'Лиса · без движения', args: { ...PixelFox.args, reducedMotion: true } }
