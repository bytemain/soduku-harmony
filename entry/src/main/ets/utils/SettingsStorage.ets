/**
 * SettingsStorage.ets — 设置项持久化
 *
 * 使用 @ohos.data.preferences 将用户设置持久化。
 * App 启动时调用 loadSettings() 恢复到 AppStorage，
 * 设置变更时调用 saveSettings() 写入磁盘。
 */
import { preferences } from '@kit.ArkData'
import { Context } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0000
const TAG = 'SettingsStorage'
const STORE_NAME = 'sudoku_settings'
const KEY_IS_LEFT_HAND = 'isLeftHand'
const KEY_HAND_MODE_MANUAL = 'handModeManual'
const KEY_GESTURE_GUIDE_SHOWN = 'gestureGuideShown'
const KEY_SHOW_COORDINATES = 'showCoordinates'
const KEY_VALIDATE_INPUT = 'validateInput'

/**
 * 获取 preferences 实例
 */
function getStore(context: Context): preferences.Preferences {
  return preferences.getPreferencesSync(context, { name: STORE_NAME })
}

/**
 * 从 Preferences 加载设置，写入 AppStorage。
 * 应在 initHandDetection() **之前**调用。
 */
export function loadSettings(context: Context): void {
  try {
    const store = getStore(context)
    const isLeftHand = store.getSync(KEY_IS_LEFT_HAND, false) as boolean
    const handModeManual = store.getSync(KEY_HAND_MODE_MANUAL, false) as boolean

    const gestureGuideShown = store.getSync(KEY_GESTURE_GUIDE_SHOWN, false) as boolean
    const showCoordinates = store.getSync(KEY_SHOW_COORDINATES, false) as boolean
    const validateInput = store.getSync(KEY_VALIDATE_INPUT, true) as boolean

    AppStorage.setOrCreate(KEY_IS_LEFT_HAND, isLeftHand)
    AppStorage.setOrCreate(KEY_HAND_MODE_MANUAL, handModeManual)
    AppStorage.setOrCreate(KEY_GESTURE_GUIDE_SHOWN, gestureGuideShown)
    AppStorage.setOrCreate(KEY_SHOW_COORDINATES, showCoordinates)
    AppStorage.setOrCreate(KEY_VALIDATE_INPUT, validateInput)

    hilog.info(DOMAIN, TAG, 'Loaded settings: isLeftHand=%{public}s, handModeManual=%{public}s, gestureGuideShown=%{public}s, showCoordinates=%{public}s, validateInput=%{public}s',
      isLeftHand.toString(), handModeManual.toString(), gestureGuideShown.toString(), showCoordinates.toString(), validateInput.toString())
  } catch (e) {
    hilog.warn(DOMAIN, TAG, 'Failed to load settings: %{public}s', JSON.stringify(e))
    // fallback: 使用默认值
    AppStorage.setOrCreate(KEY_IS_LEFT_HAND, false)
    AppStorage.setOrCreate(KEY_HAND_MODE_MANUAL, false)
    AppStorage.setOrCreate(KEY_GESTURE_GUIDE_SHOWN, false)
    AppStorage.setOrCreate(KEY_SHOW_COORDINATES, false)
    AppStorage.setOrCreate(KEY_VALIDATE_INPUT, true)
  }
}

/**
 * 将当前 AppStorage 中的设置保存到 Preferences。
 * 在设置变更时调用。
 */
export async function saveSettings(context: Context): Promise<void> {
  try {
    const store = getStore(context)
    const isLeftHand = AppStorage.get<boolean>(KEY_IS_LEFT_HAND) ?? false
    const handModeManual = AppStorage.get<boolean>(KEY_HAND_MODE_MANUAL) ?? false

    const gestureGuideShown = AppStorage.get<boolean>(KEY_GESTURE_GUIDE_SHOWN) ?? false
    const showCoordinates = AppStorage.get<boolean>(KEY_SHOW_COORDINATES) ?? false
    const validateInput = AppStorage.get<boolean>(KEY_VALIDATE_INPUT) ?? true

    store.putSync(KEY_IS_LEFT_HAND, isLeftHand)
    store.putSync(KEY_HAND_MODE_MANUAL, handModeManual)
    store.putSync(KEY_GESTURE_GUIDE_SHOWN, gestureGuideShown)
    store.putSync(KEY_SHOW_COORDINATES, showCoordinates)
    store.putSync(KEY_VALIDATE_INPUT, validateInput)
    await store.flush()

    hilog.info(DOMAIN, TAG, 'Saved settings: isLeftHand=%{public}s, handModeManual=%{public}s, gestureGuideShown=%{public}s, showCoordinates=%{public}s, validateInput=%{public}s',
      isLeftHand.toString(), handModeManual.toString(), gestureGuideShown.toString(), showCoordinates.toString(), validateInput.toString())
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'Failed to save settings: %{public}s', JSON.stringify(e))
  }
}
