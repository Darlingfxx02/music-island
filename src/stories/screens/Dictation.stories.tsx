import type { Meta, StoryObj } from '@storybook/react-vite'
import { expect, fireEvent, fn, userEvent, within } from 'storybook/test'
import { DictationSettings } from '../../features/dictation/DictationSettings'
import type { DictationController } from '../../app/useIslandApp'
import { dictationApi } from '../mocks/dictationApi'
import { dictationModels, dictationSettings, gigaamRnnt, parakeetEnglish } from '../dictationFixtures'
import { useState, type ComponentProps } from 'react'
import { defaultDictationAppearance } from '../../shared/lib/dictationAppearance'
function DictationWorkshop({ args, light }: { args: ComponentProps<typeof DictationSettings>; light: boolean }) {
  const [appearance, setAppearance] = useState(args.appearance ?? defaultDictationAppearance)
  return <div className="settings-panel" data-color-scheme={light ? 'light' : 'dark'} data-reduced-motion={args.reducedMotion || undefined} style={{ padding: 28, background: 'var(--surface-canvas)' }}><DictationSettings {...args} appearance={appearance} onAppearanceChange={setAppearance} /></div>
}
const controller: DictationController = { enabled: true, api: dictationApi, busy: null, error: null, progress: {}, enable: fn(async () => {}), disable: fn(async () => {}), loadMoreHistory: fn(async () => {}), refresh: fn(async () => {}), run: fn(async (_id, action) => { await action() }), data: { settings: dictationSettings, models: [gigaamRnnt, parakeetEnglish, ...dictationModels], history: [], microphones: [{ index: '0', name: 'Microphone (USB Audio)', is_default: true }], path: 'C:\\Users\\User\\AppData\\Roaming\\Music Island\\dictation' } }
const meta = {
  title: 'Screens/Dictation', component: DictationSettings,
  args: { controller, page: 'models', locale: 'ru', onEnable: fn(async () => {}), onPage: fn() },
  parameters: { workshop: { width: 720, note: 'Каталог Handy 0.9.7. Здесь загрузки и запись заменены локальными примерами.' } },
  render: (args, context) => <DictationWorkshop key={context.id} args={args} light={Boolean(context.parameters.light)} />,
} satisfies Meta<typeof DictationSettings>
export default meta
type Story = StoryObj<typeof meta>
export const Models: Story = { name: 'Модели · русский язык' }
export const ModelsNarrow: Story = { name: 'Модели · узкое окно', parameters: { workshop: { width: 420 } } }
export const LanguageFilter: Story = { name: 'Модели · фильтр по языкам', play: async ({ canvasElement }) => {
  const canvas = within(canvasElement)
  const trigger = canvas.getByRole('button', { name: 'Фильтр по языкам' })
  await expect(canvas.queryByRole('switch', { name: 'Показать все языки' })).not.toBeInTheDocument()
  await userEvent.click(trigger)
  const body = within(document.body)
  const options = body.getAllByRole('menuitemcheckbox')
  await expect(options[0]).toHaveTextContent('Английский')
  await expect(options[1]).toHaveTextContent('Русский')
  await userEvent.click(body.getByRole('menuitemcheckbox', { name: 'Английский' }))
  await expect(canvas.getByRole('article', { name: parakeetEnglish.name })).toBeVisible()
  await userEvent.click(body.getByRole('menuitemcheckbox', { name: 'Русский' }))
  await expect(canvas.queryByRole('article', { name: gigaamRnnt.name })).not.toBeInTheDocument()
  await expect(canvas.getByRole('article', { name: 'Whisper Small' })).toBeVisible()
  await userEvent.keyboard('{Escape}')
  await expect(body.queryByRole('menu')).not.toBeInTheDocument()
  await expect(trigger).toHaveFocus()
  await userEvent.click(trigger)
} }
export const LanguageFilterLight: Story = { ...LanguageFilter, name: 'Фильтр языков · светлая тема', parameters: { light: true } }
export const General: Story = { name: 'Микрофон и сочетание', args: { page: 'general' } }
export const WaveTheme: Story = { name: 'Тема · волны и оптический материал', args: { page: 'general', appearance: { ...defaultDictationAppearance, theme: 'wave', palette: 'prism' } } }
export const WaveWhite: Story = { name: 'Волны · белый цвет', args: { page: 'general', appearance: { ...defaultDictationAppearance, theme: 'wave', palette: 'white' } } }
export const PixelTheme: Story = { name: 'Лиса · акцент приложения', args: { page: 'general', appearance: { ...defaultDictationAppearance, theme: 'pixels' } } }
export const FoxTheme: Story = { name: 'Тема · пиксельная лиса', args: { page: 'general', appearance: { ...defaultDictationAppearance, theme: 'pixels', palette: 'ember' } } }
export const FoxLight: Story = { ...FoxTheme, name: 'Пиксельная лиса · светлая тема', parameters: { light: true } }
export const FoxWhite: Story = { ...FoxTheme, name: 'Лиса · белый цвет', args: { ...FoxTheme.args, appearance: { ...defaultDictationAppearance, theme: 'pixels', palette: 'white' } } }
export const HoldPreview: Story = { ...FoxTheme, name: 'Удержание · превью без кнопок', args: { ...FoxTheme.args, controller: { ...controller, data: { ...controller.data!, settings: { ...dictationSettings, shortcut_activation: 'push_to_talk' } } } } }
export const ThemesNarrow: Story = { ...FoxTheme, name: 'Выбор тем · узкое окно', parameters: { workshop: { width: 420 } } }
export const ThemesReducedMotion: Story = { ...FoxTheme, name: 'Выбор тем · без движения', args: { ...FoxTheme.args, reducedMotion: true } }
export const ThemeSwitching: Story = { name: 'Темы · переключение и настройки', args: { page: 'general', reducedMotion: true }, play: async ({ canvasElement }) => {
  const canvas = within(canvasElement)
  await expect(canvas.queryByRole('heading', { name: 'Тема диктовки' })).not.toBeInTheDocument()
  await expect(canvas.getByRole('radiogroup', { name: 'Тема диктовки' })).toBeVisible()
  await userEvent.click(canvas.getByRole('radio', { name: 'Лиса' }))
  await expect(canvasElement.querySelector('.dictation-preview [data-character="fox"]')).not.toBeNull()
  await expect(canvas.queryByRole('button', { name: 'Персонаж' })).not.toBeInTheDocument()
  await expect(canvas.queryAllByRole('slider')).toHaveLength(0)
  await expect(canvas.queryByRole('radio', { name: 'Спектр' })).not.toBeInTheDocument()
  await userEvent.click(canvas.getByRole('radio', { name: 'Белый' }))
  await expect(canvas.getByRole('radio', { name: 'Белый' })).toBeChecked()
  await userEvent.click(canvas.getByRole('radio', { name: 'Сакура' }))
  await expect(canvas.getByRole('radio', { name: 'Сакура' })).toBeChecked()
  await userEvent.click(canvas.getByRole('radio', { name: 'Волны' }))
  await expect(canvas.getByRole('switch', { name: 'Цветные края волн' })).toBeVisible()
  await userEvent.click(canvas.getByRole('radio', { name: 'Лиса' }))
  await expect(canvas.getByRole('radio', { name: 'Сакура' })).toBeChecked()
  await userEvent.click(canvas.getByRole('radio', { name: 'Классическая' }))
  await expect(canvas.queryByRole('radiogroup', { name: 'Цвет диктовки' })).not.toBeInTheDocument()
} }
export const History: Story = { name: 'История · пустое состояние', args: { page: 'history' } }
export const Welcome: Story = { name: 'Первое включение', args: { controller: { ...controller, data: null } } }
export const Downloading: Story = { name: 'Загрузка · 48%', args: { controller: { ...controller, busy: `download:${dictationModels[0].id}`, progress: { [dictationModels[0].id]: 48 } } } }
export const DownloadError: Story = { name: 'Загрузка · ошибка сети', args: { controller: { ...controller, error: 'Нет соединения с сервером. Проверьте подключение.' } } }
export const Light: Story = { name: 'Модели · светлая тема', parameters: { light: true } }
export const English: Story = { name: 'Models · English', args: { locale: 'en' } }
export const Dictionary: Story = { name: 'Словарь', args: { page: 'dictionary' } }
export const PostProcessing: Story = { name: 'Обработка текста · выключена', args: { page: 'processing' } }
export const Advanced: Story = { name: 'Дополнительные параметры', args: { page: 'advanced' } }
export const DownloadConsent: Story = { name: 'Перед загрузкой · путь и размер', play: async ({ canvasElement }) => {
  const canvas = within(canvasElement)
  const trigger = canvas.getAllByRole('button', { name: 'Скачать' })[0]
  await userEvent.click(trigger)
  await expect(canvas.getByRole('dialog')).toHaveTextContent('AppData')
  await expect(canvas.getByRole('dialog')).toHaveTextContent(/МБ|ГБ|MB|GB/)
  // Synthetic keys do not trigger the browser's native dialog default action.
  // Exercise the same cancel event here; real Escape is covered in browser QA.
  fireEvent(canvas.getByRole('dialog'), new Event('cancel', { cancelable: true }))
  await expect(canvas.queryByRole('dialog')).not.toBeInTheDocument()
  await expect(trigger).toHaveFocus()
  await userEvent.click(trigger)
} }
export const ImportPreview: Story = { name: 'Импорт · выбор файлов', play: async ({ canvasElement }) => {
  const canvas = within(canvasElement)
  await userEvent.click(canvas.getByRole('button', { name: 'Добавить модель' }))
  await userEvent.click(within(document.body).getByRole('menuitem', { name: 'Импорт из Handy' }))
  const dialog = await canvas.findByRole('dialog')
  await expect(dialog).toHaveTextContent('История и ключи сервисов не переносятся')
  await expect(within(dialog).getByRole('button', { name: /Скопировать/ })).toBeDisabled()
} }

const rnnt = { ...gigaamRnnt, is_downloaded: true }
export const ImportedRnnt: Story = { name: 'Импортирована GigaAM · выбрана и выгружена', args: { controller: { ...controller, data: { ...controller.data!, models: [rnnt, ...dictationModels], settings: { ...dictationSettings, selected_model: rnnt.id }, modelStatus: { is_loaded: false, current_model: null } } } }, play: async ({ canvasElement }) => {
  const installed = within(canvasElement).getByRole('region', { name: 'На компьютере' })
  await expect(installed).toHaveTextContent('GigaAM')
  await expect(installed).not.toHaveTextContent('Скачана')
  await expect(installed).toHaveTextContent('Выбрана')
  await expect(installed).not.toHaveTextContent('В памяти')
} }
export const Disabled: Story = { name: 'Диктовка выключена · настройки доступны', args: { page: 'general', controller: { ...controller, enabled: false } } }
export const DisabledLight: Story = { ...Disabled, name: 'Диктовка выключена · светлая тема', parameters: { light: true } }
export const Recording: Story = { name: 'Идёт запись', args: { page: 'general', controller: { ...controller, data: { ...controller.data!, status: { revision: 1, operationId: 1, phase: 'recording', ready: true, text: '', error: null } } } } }
export const AdvancedLight: Story = { name: 'Дополнительно · светлая тема', args: { page: 'advanced' }, parameters: { light: true } }
export const AdvancedEnglish: Story = { name: 'Дополнительно · английский', args: { page: 'advanced', locale: 'en' } }
export const AdvancedNarrow: Story = { name: 'Дополнительно · узкое окно', args: { page: 'advanced' }, parameters: { workshop: { width: 420 } } }
export const AdvancedLoadError: Story = { name: 'Дополнительно · устройства недоступны', args: { page: 'advanced', controller: { ...controller, api: { ...dictationApi, getAvailableOutputDevices: fn(async () => { throw new Error('Unavailable') }), getAvailableAccelerators: fn(async () => { throw new Error('Unavailable') }) } } } }
export const AdvancedLoading: Story = { name: 'Дополнительно · загрузка устройств', args: { page: 'advanced', controller: { ...controller, api: { ...dictationApi, getAvailableOutputDevices: fn(async () => { await new Promise(() => {}); return dictationApi.getAvailableOutputDevices() }), getAvailableAccelerators: fn(async () => { await new Promise(() => {}); return dictationApi.getAvailableAccelerators() }) } } } }
export const GeneralLight: Story = { name: 'Превью диктовки · светлая тема', args: { page: 'general', reducedMotion: true }, parameters: { light: true } }
export const MicrophoneDiagnostic: Story = { name: 'Диагностика · микрофон доступен', args: { page: 'advanced' }, play: async ({ canvasElement }) => {
  const canvas = within(canvasElement)
  await userEvent.click(canvas.getByRole('button', { name: 'Проверить микрофон' }))
  await expect(await canvas.findByText('Доступ к микрофону разрешён')).toBeVisible()
  await userEvent.click(canvas.getByText('Технические данные'))
  await expect(canvas.getByText(/"overall_access": "allowed"/)).toBeVisible()
} }
