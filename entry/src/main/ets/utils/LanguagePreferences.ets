/** 应用语言偏好：原生接口切换资源，不重启 Ability 或重建棋局。 */
import { Context } from '@kit.AbilityKit'
import { i18n } from '@kit.LocalizationKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { normalizeLanguageMode, persistLanguageMode } from './SettingsStorage'

let languageQueue: Promise<boolean> = Promise.resolve(true)

function preferredLanguage(mode: string): string {
  return mode === 'system' ? 'default' : mode
}

/** 在资源配置回调后通知动态取词组件，修订号不是页面或棋局的 identity。 */
export function refreshLocaleRevision(context: Context, language: string = ''): void {
  let locale = language
  try {
    locale = context.resourceManager.getConfigurationSync().locale || language
  } catch (_error) {
    // 回调中的语言可用于资源管理器暂时不可用时的降级。
  }
  if (locale.length === 0 || locale === AppStorage.get<string>('effectiveLocale')) return
  AppStorage.setOrCreate('effectiveLocale', locale)
  AppStorage.setOrCreate('localeRevision', (AppStorage.get<number>('localeRevision') ?? 0) + 1)
}

/** loadSettings 之后、页面加载之前执行；仅恢复偏好，不写其他用户数据。 */
export function initializeAppLanguage(context: Context): void {
  AppStorage.setOrCreate('localeRevision', 0)
  AppStorage.setOrCreate('languageRestartRequired', false)
  const mode = normalizeLanguageMode(AppStorage.get<string>('languageMode') ?? 'system')
  try {
    i18n.System.setAppPreferredLanguage(preferredLanguage(mode))
  } catch (error) {
    hilog.warn(0x0000, 'LanguagePreferences', 'Language restore deferred: %{public}s', JSON.stringify(error))
  }
  refreshLocaleRevision(context)
}

async function applyLanguage(context: Context, mode: string): Promise<boolean> {
  if (mode !== 'system' && mode !== 'zh-Hans' && mode !== 'en') return false
  const previous = normalizeLanguageMode(AppStorage.get<string>('languageMode') ?? 'system')
  if (mode === previous) return true

  // 先验证偏好能持久化，再调用会立即改变资源语言的原生接口。
  // API 失败则恢复旧偏好；任何失败均不提前改变 UI 的选中项。
  try {
    await persistLanguageMode(context, mode)
    i18n.System.setAppPreferredLanguage(preferredLanguage(mode))
  } catch (error) {
    try {
      await persistLanguageMode(context, previous)
    } catch (rollbackError) {
      hilog.error(0x0000, 'LanguagePreferences', 'Language preference rollback failed: %{public}s', JSON.stringify(rollbackError))
    }
    hilog.error(0x0000, 'LanguagePreferences', 'Language change failed: %{public}s', JSON.stringify(error))
    return false
  }

  AppStorage.setOrCreate('languageMode', mode)
  // 官方仅保证 default 在冷启动后跟随系统；不擅自重启或清空当前路由。
  AppStorage.setOrCreate('languageRestartRequired', mode === 'system')
  refreshLocaleRevision(context)
  // 配置事件负责最终刷新；下一事件循环再检查一次，兼容同步回调中的资源更新时序。
  setTimeout(() => refreshLocaleRevision(context), 0)
  return true
}

export function setAppLanguage(context: Context, mode: string): Promise<boolean> {
  const pending = languageQueue.then(() => applyLanguage(context, mode))
  languageQueue = pending.catch(() => false)
  return pending
}
