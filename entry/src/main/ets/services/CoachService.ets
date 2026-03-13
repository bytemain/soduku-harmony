/**
 * CoachService.ets — AI 数独教练
 *
 * 封装 @kit.DataAugmentationKit 的 localChatModel，
 * 提供棋盘状态注入 Prompt、流式对话、多轮上下文。
 *
 * 参考：Doc 06 §3
 */
import { localChatModel } from '@kit.DataAugmentationKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { CellData } from '../models/CellData'
import { GRID_SIZE } from '../constants/GameConstants'
import { formatStr } from '../utils/I18nHelper'

const DOMAIN = 0x0000
const TAG = 'CoachService'

/** 对话消息 */
export class ChatMessage {
  role: 'user' | 'coach' = 'user'
  content: string = ''
  isStreaming: boolean = false

  constructor(role: 'user' | 'coach', content: string, isStreaming: boolean = false) {
    this.role = role
    this.content = content
    this.isStreaming = isStreaming
  }
}

/**
 * 将棋盘 cells 转为文字描述，注入 Prompt。
 * . 表示空格，数字表示已填入。
 */
function boardToString(cells: CellData[]): string {
  const lines: string[] = []
  for (let r = 0; r < GRID_SIZE; r++) {
    const row: string[] = []
    for (let c = 0; c < GRID_SIZE; c++) {
      const cell = cells[r * GRID_SIZE + c]
      row.push(cell.value === 0 ? '.' : `${cell.value}`)
    }
    lines.push(`R${r + 1}: ${row.join(' ')}`)
  }
  return lines.join('\n')
}

/**
 * 构建教练 Prompt
 */
function buildCoachPrompt(cells: CellData[], userQuestion: string,
  getStr: (name: string) => string): string {
  const boardStr = boardToString(cells)
  return formatStr(getStr('coach_system_prompt'), boardStr, userQuestion)
}

/**
 * AI 教练服务
 */
export class CoachService {
  private questionId: number = 0
  private isInitialized: boolean = false
  private isChatting: boolean = false
  /** i18n 字符串解析函数，由调用方注入 */
  getStr: (name: string) => string = (name: string) => name

  /**
   * 初始化端侧模型（可能需要几秒）
   */
  async init(): Promise<boolean> {
    if (this.isInitialized) return true
    try {
      await localChatModel.init()
      this.isInitialized = true
      hilog.info(DOMAIN, TAG, 'localChatModel initialized')
      return true
    } catch (err) {
      const e = err as BusinessError
      hilog.error(DOMAIN, TAG, 'init failed: code=%{public}d, msg=%{public}s', e.code, e.message)
      return false
    }
  }

  /**
   * 重置对话上下文（开始新话题）
   */
  resetConversation(): void {
    this.questionId = 0
  }

  /**
   * 发送消息并流式接收回复
   * @param cells 当前棋盘状态
   * @param userMessage 用户消息
   * @param onChunk 每收到一块文字时回调（传入累积的完整文本）
   * @param onFinish 回复完成时回调（传入完整文本）
   * @param onError 出错时回调
   */
  async chat(
    cells: CellData[],
    userMessage: string,
    onChunk: (fullText: string) => void,
    onFinish: (fullText: string) => void,
    onError: (message: string) => void
  ): Promise<void> {
    if (this.isChatting) {
      onError(this.getStr('coach_busy'))
      return
    }

    if (!this.isInitialized) {
      const ok = await this.init()
      if (!ok) {
        onError(this.getStr('coach_init_failed'))
        return
      }
    }

    this.isChatting = true
    this.questionId++

    const prompt = buildCoachPrompt(cells, userMessage, this.getStr)

    const questionInfo: localChatModel.QuestionInfo = {
      questionId: this.questionId,
      content: prompt
    }
    const config: localChatModel.Config = {
      isStream: true
    }

    let fullText = ''

    try {
      await localChatModel.chat(
        questionInfo,
        config,
        async (err: BusinessError, answer: localChatModel.Answer): Promise<void> => {
          if (err) {
            hilog.error(DOMAIN, TAG, 'chat error: code=%{public}d, msg=%{public}s', err.code, err.message)
            this.isChatting = false
            onError(formatStr(this.getStr('coach_error'), err.code))
            return
          }

          if (answer.content) {
            fullText += answer.content
            onChunk(fullText)
          }

          if (answer.isFinished) {
            this.isChatting = false
            onFinish(fullText)
            hilog.info(DOMAIN, TAG, 'chat finished, questionId=%{public}d, length=%{public}d',
              this.questionId, fullText.length)
          }
        }
      )
    } catch (err) {
      this.isChatting = false
      const e = err as BusinessError
      hilog.error(DOMAIN, TAG, 'chat exception: code=%{public}d, msg=%{public}s', e.code, e.message)
      onError(formatStr(this.getStr('coach_send_failed'), e.code))
    }
  }

  /** 是否正在对话中 */
  get busy(): boolean {
    return this.isChatting
  }
}
