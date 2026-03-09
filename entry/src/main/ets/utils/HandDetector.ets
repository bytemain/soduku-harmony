/**
 * HandDetector.ets — 左右手检测
 *
 * 通过 @kit.MultimodalAwarenessKit 的 motion 模块检测握持手，
 * 自动镜像翻转操作区布局。
 *
 * 使用 holdingHandChanged 事件（握持手感知），
 * 而非 operatingHandChanged（操作手感知，需要触屏才触发）。
 *
 * DETECT_GESTURE 是 system_grant 权限，无需动态申请。
 * 不支持的设备（错误码 801）静默 fallback 到右手模式。
 *
 * 参考：Doc 05 §6, Doc 06 §四
 */
import { motion } from '@kit.MultimodalAwarenessKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Callback } from '@kit.BasicServicesKit'

const DOMAIN = 0x0000
const TAG = 'HandDetector'

/**
 * 握持手变化回调（模块级，用于 off 取消订阅）
 */
const holdingHandCallback: Callback<motion.HoldingHandStatus> =
  (data: motion.HoldingHandStatus) => {
    hilog.info(DOMAIN, TAG, '>>> holdingHandChanged callback fired, data=%{public}d', data)
    const isLeft = data === motion.HoldingHandStatus.LEFT_HAND_HELD;
    const manualMode = AppStorage.get<boolean>('handModeManual') ?? false
    hilog.info(DOMAIN, TAG, '>>> isLeft=%{public}s, manualMode=%{public}s, will update=%{public}s',
      isLeft.toString(), manualMode.toString(), (!manualMode).toString())
    if (!manualMode) {
      AppStorage.setOrCreate('isLeftHand', isLeft)
      hilog.info(DOMAIN, TAG, '>>> Updated isLeftHand to %{public}s', isLeft.toString())
    }
  }

/**
 * 初始化握持手检测。
 * 设置 AppStorage 默认值，然后直接订阅握持手变化事件。
 */
export function initHandDetection(): void {
  // 默认右手模式
  AppStorage.setOrCreate('isLeftHand', false)
  AppStorage.setOrCreate('handModeManual', false)

  hilog.info(DOMAIN, TAG, '=== initHandDetection START ===')

  // 订阅握持手变化
  try {
    motion.on('holdingHandChanged', holdingHandCallback)
    hilog.info(DOMAIN, TAG, 'Subscribed to holdingHandChanged successfully')
  } catch (err) {
    const error = err as BusinessError
    hilog.warn(DOMAIN, TAG, 'holdingHandChanged subscription FAILED (code=%{public}d): %{public}s',
      error.code, error.message)
  }

  hilog.info(DOMAIN, TAG, '=== initHandDetection END ===')
}

/**
 * 停止握持手检测（App 退出时调用）
 */
export function stopHandDetection(): void {
  try {
    motion.off('holdingHandChanged')
    hilog.info(DOMAIN, TAG, 'Unsubscribed from holdingHandChanged')
  } catch (err) {
    const error = err as BusinessError
    hilog.info(DOMAIN, TAG, 'Failed to unsubscribe holdingHandChanged: %{public}s', error.message)
  }
}
