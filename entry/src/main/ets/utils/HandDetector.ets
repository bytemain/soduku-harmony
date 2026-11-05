/** 用户主动启用自动布局后订阅握持状态；手动模式和后台不订阅。 */
import { motion } from '@kit.MultimodalAwarenessKit'
import { BusinessError, Callback } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

let subscribed: boolean = false
let acceptingEvents: boolean = false
const holdingHandCallback: Callback<motion.HoldingHandStatus> = (data: motion.HoldingHandStatus) => {
  if (acceptingEvents && !(AppStorage.get<boolean>('handModeManual') ?? true)) {
    AppStorage.setOrCreate('isLeftHand', data === motion.HoldingHandStatus.LEFT_HAND_HELD)
  }
}

export function initHandDetection(): void {
  if (!AppStorage.has('isLeftHand')) AppStorage.setOrCreate('isLeftHand', false)
  if (!AppStorage.has('handModeManual')) AppStorage.setOrCreate('handModeManual', true)
  if (AppStorage.get<boolean>('handModeManual') ?? true) {
    stopHandDetection()
    return
  }
  if (subscribed) {
    acceptingEvents = true
    return
  }
  try {
    motion.on('holdingHandChanged', holdingHandCallback)
    subscribed = true
    acceptingEvents = true
  } catch (err) {
    const error = err as BusinessError
    // 不支持握持感知时仍可通过设置手动调整布局。
    hilog.warn(0x0000, 'HandDetector', 'Hand detection unavailable: %{public}d', error.code)
  }
}

export function stopHandDetection(): void {
  // 先拒绝已排队的回调；即使系统取消订阅失败，后台也不消费状态。
  acceptingEvents = false
  if (!subscribed) return
  try {
    motion.off('holdingHandChanged', holdingHandCallback)
    subscribed = false
  } catch (err) {
    const error = err as BusinessError
    hilog.warn(0x0000, 'HandDetector', 'Unable to stop hand detection: %{public}d', error.code)
  }
}
