import { getLocalizedString } from '../utils/I18nHelper'
import { router } from '@kit.ArkUI'
import { ColorsConfig, getThemeColors } from '../constants/GameConstants'

@Entry
@Component
struct PrivacyPage {
  private getPalette(): ColorsConfig {
    return getThemeColors(this.isDarkMode)
  }

  @StorageProp('localeRevision') private localeRevision: number = 0
  @StorageProp('isDarkMode') isDarkMode: boolean = false
  @StorageProp('topRectHeight') topRectHeight: number = 0
  @StorageProp('bottomRectHeight') bottomRectHeight: number = 0
  @StorageProp('leftRectWidth') leftRectWidth: number = 0
  @StorageProp('rightRectWidth') rightRectWidth: number = 0
  private sections: string[] = ['operator', 'local', 'clipboard', 'hand', 'backup', 'rights']

  private text(key: string): string {
    return getLocalizedString(getContext(this), key, this.localeRevision)
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Button({ type: ButtonType.Normal }) {
          Image($r('app.media.paper_arrow_left'))
            .width(24)
            .height(24)
            .fillColor(this.getPalette().titleText)
            .accessibilityLevel('no')
        }
        .id('privacy-back')
        .width(44)
        .height(44)
        .padding(10)
        .borderRadius(8)
        .backgroundColor(Color.Transparent)
        .accessibilityText($r('app.string.common_back'))
        .onClick(() => router.back())
        Text($r('app.string.privacy_support_title'))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getPalette().titleText)
      }
      .width('100%')
      .constraintSize({ maxWidth: 760 })
      .padding({ top: this.topRectHeight + 8, left: 12, right: 24, bottom: 12 })
      Scroll() {
        Column({ space: 24 }) {
          ForEach(this.sections, (section: string) => {
            Column({ space: 8 }) {
              Text(this.text('privacy_' + section + '_title'))
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getPalette().titleText)
              Text(this.text('privacy_' + section + '_body'))
                .fontSize(15)
                .lineHeight(25)
                .fontColor(this.getPalette().titleText)
                .copyOption(CopyOptions.LocalDevice)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }, (section: string) => section)
        }
        .width('100%')
        .constraintSize({ maxWidth: 760 })
        .padding({ left: 24, right: 24, top: 8, bottom: this.bottomRectHeight + 32 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .padding({ left: this.leftRectWidth, right: this.rightRectWidth })
    .backgroundColor(this.getPalette().pageBg)
  }
}
