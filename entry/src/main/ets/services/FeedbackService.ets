import { common } from '@kit.AbilityKit'
import { media } from '@kit.MediaKit'
import { audio } from '@kit.AudioKit'
import { vibrator } from '@kit.SensorServiceKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0000
const TAG = 'FeedbackService'
const DEFAULT_PRIORITY = 1

export enum FeedbackType {
  FILL = 0,
  NOTE = 1,
  ERROR = 2,
  COMPLETE = 3,
}

export function getFeedbackRawFileName(type: FeedbackType): string {
  switch (type) {
    case FeedbackType.FILL:
      return 'feedback_fill.wav'
    case FeedbackType.NOTE:
      return 'feedback_note.wav'
    case FeedbackType.ERROR:
      return 'feedback_error.wav'
    case FeedbackType.COMPLETE:
      return 'feedback_complete.wav'
    default:
      return 'feedback_fill.wav'
  }
}

export function getFeedbackVolume(type: FeedbackType): number {
  switch (type) {
    case FeedbackType.NOTE:
      return 0.55
    case FeedbackType.ERROR:
      return 0.95
    case FeedbackType.COMPLETE:
      return 1.0
    case FeedbackType.FILL:
    default:
      return 0.75
  }
}

export function shouldVibrateForFeedback(type: FeedbackType): boolean {
  return type !== FeedbackType.FILL
}

export function getFeedbackVibrationDuration(type: FeedbackType): number {
  switch (type) {
    case FeedbackType.NOTE:
      return 20
    case FeedbackType.ERROR:
      return 120
    case FeedbackType.COMPLETE:
      return 180
    case FeedbackType.FILL:
    default:
      return 0
  }
}

export function getFeedbackHapticUsage(type: FeedbackType): vibrator.Usage {
  switch (type) {
    case FeedbackType.NOTE:
      return vibrator.Usage.USAGE_TOUCH
    case FeedbackType.ERROR:
      return vibrator.Usage.USAGE_NOTIFICATION
    case FeedbackType.COMPLETE:
      return vibrator.Usage.USAGE_ALARM
    case FeedbackType.FILL:
    default:
      return vibrator.Usage.USAGE_TOUCH
  }
}

export class FeedbackService {
  private static instance: FeedbackService = new FeedbackService()
  private soundPool: media.SoundPool | null = null
  private isPreparing: boolean = false
  private isPrepared: boolean = false
  private soundIds: number[] = [0, 0, 0, 0]
  private pendingSoundPlay: boolean[] = [false, false, false, false]

  static getInstance(): FeedbackService {
    return FeedbackService.instance
  }

  prepare(context: common.UIAbilityContext): void {
    if (this.isPreparing || this.isPrepared) {
      return
    }

    this.isPreparing = true
    const rendererInfo: audio.AudioRendererInfo = {
      usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
      rendererFlags: 0
    }

    media.createSoundPool(4, rendererInfo).then((pool: media.SoundPool) => {
      this.soundPool = pool
      this.isPrepared = true
      this.isPreparing = false
      this.preloadAllSounds(context)
    }).catch((err: BusinessError) => {
      this.isPreparing = false
      hilog.warn(DOMAIN, TAG, 'Failed to create sound pool: %{public}s', JSON.stringify(err))
    })
  }

  play(context: common.UIAbilityContext, type: FeedbackType): void {
    if (this.soundPool === null || this.soundIds[type] === 0) {
      this.pendingSoundPlay[type] = true
    }
    this.prepare(context)
    this.playSound(type)
    this.playHaptic(type)
  }

  private preloadAllSounds(context: common.UIAbilityContext): void {
    for (let i = 0; i < 4; i++) {
      this.preloadSingleSound(context, i as FeedbackType)
    }
  }

  private preloadSingleSound(context: common.UIAbilityContext, type: FeedbackType): void {
    if (this.soundPool === null || this.soundIds[type] !== 0) {
      return
    }

    const fileName = getFeedbackRawFileName(type)
    context.resourceManager.getRawFd(fileName).then((rawFd) => {
      if (this.soundPool === null) {
        return
      }
      this.soundPool.load(rawFd.fd, rawFd.offset, rawFd.length).then((soundId: number) => {
        this.soundIds[type] = soundId
        if (this.pendingSoundPlay[type]) {
          this.pendingSoundPlay[type] = false
          this.playSound(type)
        }
      }).catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'Failed to load sound %{public}s: %{public}s', fileName, JSON.stringify(err))
      })
    }).catch((err: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'Failed to open raw sound %{public}s: %{public}s', fileName, JSON.stringify(err))
    })
  }

  private isSoundEnabled(): boolean {
    return AppStorage.get<boolean>('soundEnabled') ?? true
  }

  private isHapticEnabled(): boolean {
    return AppStorage.get<boolean>('hapticEnabled') ?? true
  }

  private playSound(type: FeedbackType): void {
    if (!this.isSoundEnabled() || this.soundPool === null) {
      return
    }

    const soundId = this.soundIds[type]
    if (soundId === 0) {
      return
    }

    const volume = getFeedbackVolume(type)
    const params: media.PlayParameters = {
      loop: 0,
      rate: audio.AudioRendererRate.RENDER_RATE_NORMAL,
      leftVolume: volume,
      rightVolume: volume,
      priority: DEFAULT_PRIORITY
    }

    this.soundPool.play(soundId, params, (err: BusinessError | undefined, streamId: number) => {
      if (err) {
        hilog.warn(DOMAIN, TAG, 'Failed to play sound %{public}d on stream %{public}d: %{public}s',
          soundId, streamId, JSON.stringify(err))
      }
    })
  }

  private playHaptic(type: FeedbackType): void {
    if (!this.isHapticEnabled() || !shouldVibrateForFeedback(type)) {
      return
    }

    const duration = getFeedbackVibrationDuration(type)
    if (duration <= 0) {
      return
    }

    vibrator.startVibration({
      type: 'time',
      duration: duration
    }, {
      id: 0,
      usage: getFeedbackHapticUsage(type)
    }).catch((err: BusinessError) => {
      hilog.info(DOMAIN, TAG, 'Vibration unavailable: %{public}s', JSON.stringify(err))
    })
  }
}
