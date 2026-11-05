/** 首页折叠入口在组件内读取翻译，避免 Builder 按值参数保留切换前的文案。 */
import { ColorsConfig, getThemeColors } from '../constants/GameConstants'
import { getLocalizedString } from '../utils/I18nHelper'

@Component
export struct HomeDisclosureRow {
  @Prop labelKey: string = ''
  @Prop expanded: boolean = false
  onToggle: () => void = () => {}

  @StorageProp('localeRevision') private localeRevision: number = 0
  @StorageProp('isDarkMode') private isDarkMode: boolean = false

  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  private label(): string {
    return getLocalizedString(getContext(this), this.labelKey, this.localeRevision)
  }

  build() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 12 }) {
        Text(this.label())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getPalette().titleText)
          .layoutWeight(1)
          .textAlign(TextAlign.Start)
        Image($r('app.media.paper_arrow_right'))
          .width(18)
          .height(18)
          .fillColor(this.getPalette().subtitleText)
          .rotate({ angle: this.expanded ? -90 : 90 })
          .accessibilityLevel('no')
      }
      .width('100%')
    }
    .width('100%')
    .height(52)
    .padding({ left: 0, right: 0 })
    .borderRadius(0)
    .backgroundColor(Color.Transparent)
    .accessibilityText(this.label())
    .accessibilityDescription(this.expanded ? $r('app.string.home_expanded') : $r('app.string.home_collapsed'))
    .onClick(() => this.onToggle())
  }
}
