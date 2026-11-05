import { AbilityConstant, ConfigurationConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { text } from '@kit.ArkGraphics2D';
import { loadSettings } from '../utils/SettingsStorage';
import { initializeAppLanguage, refreshLocaleRevision } from '../utils/LanguagePreferences';
import { Colors, applyTheme } from '../constants/GameConstants';
import { PAPER_DIGIT_FAMILY } from '../constants/Typography';

const DOMAIN = 0x0000;

interface HandDetectionService {
  initHandDetection: () => void;
  stopHandDetection: () => void;
}

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;
  private isWearable: boolean = deviceInfo.deviceType === 'wearable';
  private foreground: boolean = false;
  private handService: HandDetectionService | null = null;
  private loadingHandService: boolean = false;
  private avoidAreaHandler = (_data: window.AvoidAreaOptions): void => {
    this.updateAvoidAreas();
  };

  /** 页面加载前同步注册本地字体，避免首帧闪回系统字形；手表保持原有字体。 */
  private registerPaperDigitFont(): void {
    if (this.isWearable || !canIUse('SystemCapability.Graphics.Drawing')) return;
    try {
      text.FontCollection.getGlobalInstance().loadFontSync(
        PAPER_DIGIT_FAMILY, $rawfile('fonts/SourceSerif4-Regular.ttf'));
    } catch (err) {
      // fontFamily 的后备项仍可正常显示数字，字体问题不阻止启动。
      hilog.warn(DOMAIN, 'EntryAbility', 'Paper digit font unavailable; using system font: %{public}s',
        JSON.stringify(err));
    }
  }

  // WATCH 5 has no Motion SysCap: do not even load its native module on the watch.
  private async startPhoneHandDetection(): Promise<void> {
    if (this.isWearable || !this.foreground ||
      !canIUse('SystemCapability.MultimodalAwareness.Motion')) return;
    if (this.handService) {
      this.handService.initHandDetection();
      return;
    }
    if (this.loadingHandService) return;
    this.loadingHandService = true;
    try {
      const service = await import('../utils/HandDetector');
      this.handService = service;
      if (this.foreground) service.initHandDetection();
    } catch (err) {
      hilog.warn(DOMAIN, 'EntryAbility', 'Hand detection unavailable: %{public}s', JSON.stringify(err));
    } finally {
      this.loadingHandService = false;
    }
  }

  private updateAvoidAreas(): void {
    if (!this.mainWindow || this.isWearable) return;
    try {
      const system = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const navigation = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const cutout = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      const uiContext = this.mainWindow.getUIContext();
      AppStorage.setOrCreate('topRectHeight', uiContext.px2vp(Math.max(
        system.topRect.height, navigation.topRect.height, cutout.topRect.height)));
      AppStorage.setOrCreate('bottomRectHeight', uiContext.px2vp(Math.max(
        system.bottomRect.height, navigation.bottomRect.height, cutout.bottomRect.height)));
      AppStorage.setOrCreate('leftRectWidth', uiContext.px2vp(Math.max(
        system.leftRect.width, navigation.leftRect.width, cutout.leftRect.width)));
      AppStorage.setOrCreate('rightRectWidth', uiContext.px2vp(Math.max(
        system.rightRect.width, navigation.rightRect.width, cutout.rightRect.width)));
    } catch (err) {
      hilog.warn(DOMAIN, 'EntryAbility', 'Avoid area unavailable: %{public}s', JSON.stringify(err));
    }
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');

    AppStorage.setOrCreate('isWearable', this.isWearable);
    AppStorage.setOrCreate('appInForeground', false);
    AppStorage.setOrCreate('topRectHeight', 0);
    AppStorage.setOrCreate('bottomRectHeight', 0);
    AppStorage.setOrCreate('leftRectWidth', 0);
    AppStorage.setOrCreate('rightRectWidth', 0);
    loadSettings(this.context);
    initializeAppLanguage(this.context);
    if (!this.isWearable) {
      import('../utils/StatsStorage').then((stats) => stats.reconcileJournalStats(this.context))
        .catch((err: Error) => hilog.warn(DOMAIN, 'EntryAbility', 'Journal stats reconciliation deferred: %{public}s', err.message));
    }
    this.registerPaperDigitFont();

    // 根据用户保存的主题偏好设置 colorMode
    const themeMode = AppStorage.get<string>('themeMode') ?? 'system';
    try {
      if (themeMode === 'light') {
        this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else if (themeMode === 'dark') {
        this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else {
        this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }

    // 检测当前系统颜色模式并初始化主题
    const isDark = themeMode === 'dark' ||
      (themeMode === 'system' && this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    AppStorage.setOrCreate('isDarkMode', isDark);
    applyTheme(isDark);
    hilog.info(DOMAIN, 'testTag', 'Initial color mode: themeMode=%{public}s, isDark=%{public}s',
      themeMode, String(isDark));
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
    this.foreground = false;
    AppStorage.setOrCreate('appInForeground', false);
    this.handService?.stopHandDetection();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent(this.isWearable ? 'pages/WatchHomePage' : 'pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');

      // 获取主窗口
      let windowClass = windowStage.getMainWindowSync();
      this.mainWindow = windowClass;
      if (this.isWearable) return;
      // Respect the system rotation lock while supporting landscape and wide foldables.
      windowClass.setPreferredOrientation(window.Orientation.AUTO_ROTATION_RESTRICTED).catch((err: Error) => {
        hilog.warn(DOMAIN, 'EntryAbility', 'Orientation preference unavailable: %{public}s', JSON.stringify(err));
      });

      // 1. 设置窗口全屏布局（沉浸式）
      windowClass.setWindowLayoutFullScreen(true).then(() => {
        hilog.info(DOMAIN, 'testTag', 'Succeeded in setting the window layout to full-screen mode.');
      }).catch((err: Error) => {
        hilog.error(DOMAIN, 'testTag', 'Failed to set full-screen mode. Cause: %{public}s', JSON.stringify(err));
      });

      // 2. 设置状态栏和导航栏透明，根据深色模式动态设置文字颜色
      const isDark = AppStorage.get<boolean>('isDarkMode') ?? false;
      this.updateSystemBarStyle(windowClass, isDark);

      // Re-query every side after rotation/folding; use this window's density.
      this.updateAvoidAreas();
      windowClass.on('avoidAreaChange', this.avoidAreaHandler);
    });
  }

  /**
   * 监听系统配置变化（包括深色模式切换）
   * 当用户手动设置了 light/dark 时，仍需响应 setColorMode 触发的变化
   */
  onConfigurationUpdate(newConfig: Configuration): void {
    // 语言配置不一定附带颜色变化，必须在主题的提前返回之前处理。
    refreshLocaleRevision(this.context, newConfig.language ?? '');
    hilog.info(DOMAIN, 'testTag', 'onConfigurationUpdate: colorMode=%{public}s',
      String(newConfig.colorMode));

    // 非颜色配置变化不应重置主题；手动主题始终优先于系统颜色模式。
    if (newConfig.colorMode !== ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT &&
      newConfig.colorMode !== ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      return;
    }
    const themeMode = AppStorage.get<string>('themeMode') ?? 'system';
    const isDark = themeMode === 'dark' || (themeMode === 'system' &&
      newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    const wasDark = AppStorage.get<boolean>('isDarkMode') ?? false;

    if (isDark !== wasDark) {
      applyTheme(isDark);
      AppStorage.setOrCreate('isDarkMode', isDark);
      hilog.info(DOMAIN, 'testTag', 'Theme switched: isDark=%{public}s', String(isDark));

    }
    // 设置面板会先更新 AppStorage，回调时值可能已经相同，但系统栏仍需同步。
    if (this.mainWindow && !this.isWearable) {
      this.updateSystemBarStyle(this.mainWindow, isDark);
    }
  }

  /**
   * 根据深色模式设置状态栏/导航栏文字颜色
   * 深色模式下文字为白色，浅色模式下为黑色
   */
  private updateSystemBarStyle(windowClass: window.Window, isDark: boolean): void {
    const contentColor = Colors.systemBarContent;
    let sysBarProps: window.SystemBarProperties = {
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: contentColor,
      navigationBarContentColor: contentColor
    };
    windowClass.setWindowSystemBarProperties(sysBarProps).then(() => {
      hilog.info(DOMAIN, 'testTag', 'System bar style updated: isDark=%{public}s', String(isDark));
    }).catch((err: Error) => {
      hilog.error(DOMAIN, 'testTag', 'Failed to set system bar properties. Cause: %{public}s', JSON.stringify(err));
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
    if (this.mainWindow && !this.isWearable) {
      this.mainWindow.off('avoidAreaChange', this.avoidAreaHandler);
    }
    this.mainWindow = null;
  }

  onForeground(): void {
    this.foreground = true;
    AppStorage.setOrCreate('appInForeground', true);
    refreshLocaleRevision(this.context);
    this.startPhoneHandDetection();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    this.foreground = false;
    AppStorage.setOrCreate('appInForeground', false);
    this.handService?.stopHandDetection();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
