/** 历史列表独立入口及可返回调用页的棋局详情。 */
import { router } from '@kit.ArkUI'
import { ColorsConfig, getThemeColors } from '../constants/GameConstants'
import { JournalPanel } from '../components/JournalPanel'
import { HistoryList } from '../components/HistoryList'

class HistoryPageParams {
  journalSessionId?: string
  journalNodeId?: string
  journalBranchId?: string
  returnToCaller?: boolean
}

@Entry
@Component
struct HistoryPage {
  @StorageProp('isDarkMode') private isDarkMode: boolean = false
  @StorageProp('topRectHeight') private topRectHeight: number = 0
  @StorageProp('bottomRectHeight') private bottomRectHeight: number = 0
  @StorageProp('leftRectWidth') private leftRectWidth: number = 0
  @StorageProp('rightRectWidth') private rightRectWidth: number = 0
  @State private selectedSessionId: string = ''
  @State private initialNodeId: string = ''
  @State private initialBranchId: string = ''
  @State private detailVersion: number = 0
  private returnToCaller: boolean = false

  private getPalette(): ColorsConfig { return getThemeColors(this.isDarkMode) }

  aboutToAppear(): void {
    const params = router.getParams() as HistoryPageParams | null
    this.selectedSessionId = params?.journalSessionId ?? ''
    this.returnToCaller = params?.returnToCaller ?? false
    this.initialNodeId = params?.journalNodeId ?? ''
    this.initialBranchId = params?.journalBranchId ?? ''
  }

  onPageShow(): void { this.detailVersion++ }

  onBackPress(): boolean {
    if (this.selectedSessionId.length === 0 || this.returnToCaller) return false
    this.closeDetail()
    return true
  }

  private closeDetail(): void {
    if (this.returnToCaller) {
      router.back()
      return
    }
    this.selectedSessionId = ''
    this.initialNodeId = ''
    this.initialBranchId = ''
  }

  build() {
    Column() {
      if (this.selectedSessionId.length > 0) {
        ForEach([this.detailVersion], (_version: number) => {
          JournalPanel({
            sessionId: this.selectedSessionId,
            initialNodeId: this.initialNodeId,
            initialBranchId: this.initialBranchId,
            inGame: false,
            onClose: () => { this.closeDetail() },
            onRestore: (sessionId: string, nodeId: string, fork: boolean, branchId?: string) => {
              router.pushUrl({
                url: 'pages/GamePage',
                params: { journalSessionId: sessionId, journalNodeId: nodeId, journalFork: fork, journalBranchId: branchId ?? '' },
              })
            },
          })
        }, (version: number) => version.toString())
      } else {
        Column() {
          HistoryList({ showBack: true, refreshVersion: this.detailVersion })
        }
        .width('100%').height('100%')
        .padding({ top: this.topRectHeight, bottom: this.bottomRectHeight,
          left: this.leftRectWidth, right: this.rightRectWidth })
      }
    }
    .width('100%').height('100%')
    .backgroundColor(this.getPalette().pageBg)
    .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.CUTOUT], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
