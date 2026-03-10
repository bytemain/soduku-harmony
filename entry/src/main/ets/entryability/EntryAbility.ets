import { AbilityConstant, ConfigurationConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { initHandDetection, stopHandDetection } from '../utils/HandDetector';
import { loadSettings } from '../utils/SettingsStorage';
import { applyTheme } from '../constants/GameConstants';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');

    // 先恢复持久化的设置（包含 themeMode），再初始化手检测
    loadSettings(this.context);
    initHandDetection();

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
    stopHandDetection();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');

      // 获取主窗口
      let windowClass = windowStage.getMainWindowSync();
      this.mainWindow = windowClass;

      // 1. 设置窗口全屏布局（沉浸式）
      windowClass.setWindowLayoutFullScreen(true).then(() => {
        hilog.info(DOMAIN, 'testTag', 'Succeeded in setting the window layout to full-screen mode.');
      }).catch((err: Error) => {
        hilog.error(DOMAIN, 'testTag', 'Failed to set full-screen mode. Cause: %{public}s', JSON.stringify(err));
      });

      // 2. 设置状态栏和导航栏透明，根据深色模式动态设置文字颜色
      const isDark = AppStorage.get<boolean>('isDarkMode') ?? false;
      this.updateSystemBarStyle(windowClass, isDark);

      // 3. 获取避让区域高度，存入 AppStorage 供页面使用
      let statusBarArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      let navIndicatorArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      AppStorage.setOrCreate('topRectHeight', px2vp(statusBarArea.topRect.height));
      AppStorage.setOrCreate('bottomRectHeight', px2vp(navIndicatorArea.bottomRect.height));

      // 4. 监听避让区域变化（如折叠屏状态切换）
      windowClass.on('avoidAreaChange', (data) => {
        if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
          AppStorage.setOrCreate('topRectHeight', px2vp(data.area.topRect.height));
        } else if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          AppStorage.setOrCreate('bottomRectHeight', px2vp(data.area.bottomRect.height));
        }
      });
    });
  }

  /**
   * 监听系统配置变化（包括深色模式切换）
   * 当用户手动设置了 light/dark 时，仍需响应 setColorMode 触发的变化
   */
  onConfigurationUpdate(newConfig: Configuration): void {
    hilog.info(DOMAIN, 'testTag', 'onConfigurationUpdate: colorMode=%{public}s',
      String(newConfig.colorMode));

    const isDark = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    const wasDark = AppStorage.get<boolean>('isDarkMode') ?? false;

    if (isDark !== wasDark) {
      applyTheme(isDark);
      AppStorage.setOrCreate('isDarkMode', isDark);
      hilog.info(DOMAIN, 'testTag', 'Theme switched: isDark=%{public}s', String(isDark));

      // 更新状态栏文字颜色
      if (this.mainWindow) {
        this.updateSystemBarStyle(this.mainWindow, isDark);
      }
    }
  }

  /**
   * 根据深色模式设置状态栏/导航栏文字颜色
   * 深色模式下文字为白色，浅色模式下为黑色
   */
  private updateSystemBarStyle(windowClass: window.Window, isDark: boolean): void {
    const contentColor = isDark ? '#FFFFFF' : '#000000';
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
    this.mainWindow = null;
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
