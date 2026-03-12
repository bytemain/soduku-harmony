# 🌍 ArkUI 跨平台应用调研

> ArkUI 能不能直接生成 Android、iOS 甚至 macOS 应用？本文系统调研了 **ArkUI-X** 跨平台框架的能力边界、
> 架构原理、开发流程、生态现状，以及**对我们数独项目的可行性评估**。

---

## 一、结论先行

| 目标平台 | 是否可行 | 方案 | 成熟度 |
|---------|---------|------|--------|
| **Android** | ✅ 可行 | ArkUI-X，一套 ArkTS 代码编译为 APK | 🟢 正式支持，API 26+（Android 8.0+） |
| **iOS** | ✅ 可行 | ArkUI-X，一套 ArkTS 代码编译为 IPA | 🟢 正式支持，iOS 10+ |
| **macOS** | ❌ 暂不可行 | 官方未支持，roadmap 中列为未来方向 | 🔴 无官方 SDK，社区有初步探索 |
| **Windows** | ❌ 暂不可行 | 同上 | 🔴 无官方 SDK |
| **Web** | ❌ 暂不可行 | 同上 | 🔴 无官方 SDK |

**一句话总结：通过 ArkUI-X，我们的数独 App 可以用同一套 ArkTS 代码，同时部署到 HarmonyOS、Android 和 iOS 三个平台。macOS/Windows/Web 暂不支持。**

---

## 二、ArkUI-X 是什么

### 2.1 定位

ArkUI-X 是华为开源的跨平台 UI 框架，核心理念是**"一次开发，多端部署"**：

```
ArkUI（HarmonyOS 原生 UI 框架）
    ↓ 扩展
ArkUI-X（跨平台框架）
    ↓ 部署到
HarmonyOS / Android / iOS
```

- **开源地址**：[GitHub](https://github.com/arkui-x) / [Gitee](https://gitee.com/arkui-x)
- **最新版本**：ArkUI-X 5.0.4（2025 年发布，基于 API 16）
- **开发语言**：ArkTS（TypeScript 超集），与我们现有代码完全兼容
- **开发工具**：DevEco Studio 4.0+ / ACE Tools 命令行

### 2.2 与竞品定位对比

| 特性 | ArkUI-X | Flutter | React Native |
|------|---------|---------|--------------|
| 语言 | ArkTS (TS 超集) | Dart | JavaScript/TS |
| 渲染方式 | 自绘引擎 (Skia) | 自绘引擎 (Impeller/Skia) | 原生控件桥接 |
| HarmonyOS 支持 | ✅ 原生一等公民 | ✅ 官方适配中 | ⚠️ 社区适配 |
| Android/iOS | ✅ | ✅ | ✅ |
| 桌面 (Win/Mac/Linux) | ❌ | ✅ | ⚠️ 需第三方 |
| Web | ❌ | ✅ | ✅ (React Native Web) |
| 生态成熟度 | 🟡 成长期 | 🟢 成熟 | 🟢 成熟 |
| 学习曲线 | 低（已会 ArkTS） | 中（需学 Dart） | 低（JS/TS） |

---

## 三、架构原理

### 3.1 总体架构

```
┌──────────────────────────────────────┐
│           ArkTS 应用代码              │ ← 我们的数独代码
│  (UI 声明 + 业务逻辑 + 状态管理)      │
├──────────────────────────────────────┤
│         ArkUI 框架层                  │
│  (声明式 UI 引擎 + 组件 + 动画)       │
├──────────────────────────────────────┤
│       平台抽象层 (PAL)                │
│  (生命周期 / 资源 / 权限 / 事件)       │
├───────────┬───────────┬──────────────┤
│ HarmonyOS │  Android  │     iOS      │
│  原生渲染  │ Skia 自绘  │  Skia 自绘   │
│   .hap    │   .apk    │    .ipa      │
└───────────┴───────────┴──────────────┘
```

### 3.2 关键技术点

| 层次 | 说明 |
|------|------|
| **ArkTS 运行时** | Ark Compiler 编译 ArkTS 为各平台字节码/Native 模块 |
| **渲染引擎** | HarmonyOS 走原生渲染管线；Android/iOS 通过 Skia 自绘，保证 UI 一致性 |
| **平台桥接 (Bridge)** | 类似 Flutter 的 Platform Channel，用于调用原生能力（相机、定位等） |
| **资源管理** | 统一资源格式，支持多语言、分辨率适配，跨平台自动处理 |

### 3.3 工程目录结构

ArkUI-X 项目在标准 HarmonyOS 工程基础上增加 `.arkui-x` 目录：

```
soduku-harmony/
├── entry/                    # 主模块（ArkTS 代码，三端共享）
│   └── src/main/ets/        # 我们的数独代码 ← 无需修改
├── AppScope/                 # 应用配置
├── .arkui-x/                 # ← 新增：跨平台配置
│   ├── android/             # Android 工程壳（Gradle + Activity）
│   │   ├── app/
│   │   │   ├── src/main/
│   │   │   │   ├── AndroidManifest.xml
│   │   │   │   └── java/.../EntryEntryAbilityActivity.java
│   │   │   └── build.gradle
│   │   └── build.gradle
│   └── ios/                 # iOS 工程壳（Xcode Project）
│       ├── app/
│       │   ├── AppDelegate.m
│       │   └── Info.plist
│       └── app.xcodeproj
└── build-profile.json5
```

---

## 四、开发流程

### 4.1 环境搭建

**前置要求：**

| 需求 | 说明 |
|------|------|
| DevEco Studio 4.1+ | 已内置 ArkUI-X 支持 |
| ArkUI-X SDK | 在 IDE Settings → ArkUI-X 中配置 |
| Android SDK | API 26+，配置 `ANDROID_HOME` 环境变量 |
| Xcode 14+ | 仅 macOS，用于 iOS 编译 |
| Node.js 14/16 | ACE Tools 依赖（注意：高版本可能不兼容） |

**环境检测命令：**

```bash
# 安装 ACE Tools 后
ace check
# 会检测 ArkUI-X SDK / Android SDK / iOS 工具链 安装完整性
```

### 4.2 项目创建/改造

#### 方式一：新建跨平台项目

```
DevEco Studio → File → New → Create Project
→ 选择 [ArkUI-X] Empty Ability 模板
→ 自动生成三端工程结构
```

#### 方式二：改造现有项目（我们的情况）

```bash
# 1. 用 ACE Tools 在现有工程中初始化跨平台支持
ace create --type crossplatform

# 2. 生成 .arkui-x/android 和 .arkui-x/ios 目录
# 3. 主代码（entry/src/main/ets/）保持不变
```

### 4.3 编译与打包

```bash
# 编译 Android APK
ace build apk

# 编译 iOS APP（需在 macOS 上执行）
ace build ios

# 编译 HarmonyOS HAP（原有方式不变）
hvigorw assembleHap
```

也可以在 DevEco Studio 中通过菜单操作：

```
Build → Build Hap(s)/APP(s) → Build APP(s)
→ 分别选择目标平台
```

### 4.4 调试与测试

| 平台 | 调试方式 |
|------|---------|
| HarmonyOS | DevEco Studio 直接 Run，HDC 部署 |
| Android | 生成 APK 后用 Android Studio 推送到真机/模拟器 |
| iOS | 生成 Xcode 工程后用 Xcode 真机调试（需开发者账号） |

---

## 五、对数独项目的可行性评估

### 5.1 代码复用率分析

我们的数独 App 主要用到以下能力：

| 能力 | ArkUI-X 跨平台支持 | 备注 |
|------|-------------------|------|
| **声明式 UI 组件** (Row/Column/Grid/Text/Button) | ✅ 完全支持 | 基础 UI 组件跨平台一致 |
| **状态管理** (@State/@Prop/@Link/AppStorage) | ✅ 完全支持 | V2 状态管理也可用 |
| **动画** (animateTo/transition) | ✅ 支持 | Skia 渲染保证一致性 |
| **手势识别** (GestureKey 滑动输入) | ✅ 支持 | 触摸事件跨平台统一 |
| **本地存储** (Preferences) | ✅ 支持 | 跨平台 KV 存储 |
| **Worker 多线程** | ✅ 支持 | 数独求解器可继续用 Worker |
| **页面路由** (router) | ✅ 支持 | 页面导航跨平台统一 |
| **Core Vision Kit (OCR)** | ❌ 仅 HarmonyOS | 需为 Android/iOS 找替代方案 |
| **DataAugmentation Kit (AI 教练)** | ❌ 仅 HarmonyOS | 需为 Android/iOS 找替代方案 |
| **分布式数据同步** | ❌ 仅 HarmonyOS | HarmonyOS 独有能力 |

**估算代码复用率：~85%**

核心的数独逻辑（算法、状态管理、UI）可以完全复用。仅 HarmonyOS 专属 Kit（OCR、AI 教练、分布式同步）需要通过 Platform Bridge 为 Android/iOS 提供替代实现。

### 5.2 需要额外处理的部分

```
需要跨平台适配的模块：
├── OCR 拍照识别
│   ├── Android → ML Kit / Tesseract
│   └── iOS → Vision Framework
├── AI 数独教练
│   ├── Android → Gemini Nano / 本地 LLM
│   └── iOS → Core ML
└── 分布式同步
    ├── Android → Firebase Realtime DB
    └── iOS → CloudKit / Firebase
```

### 5.3 已知限制与风险

| 风险 | 说明 | 应对策略 |
|------|------|---------|
| **第三方库生态弱** | 地图、支付等开箱即用的库少 | 数独 App 不依赖这些，影响小 |
| **部分 API 不支持** | 最新 HarmonyOS API 可能未跨平台适配 | 使用前查阅官方组件支持列表 |
| **iOS 编译需 Mac** | Xcode 只能在 macOS 运行 | CI/CD 需配置 macOS Runner |
| **性能差异** | Android/iOS 走 Skia 自绘，可能微弱性能差异 | 数独 App 性能要求不高，影响极小 |
| **API 变化快** | ArkUI-X 还在快速迭代，API 可能变动 | 锁定 SDK 版本，关注 Release Notes |

---

## 六、与其他跨平台方案对比

### 6.1 方案对比矩阵

| 维度 | ArkUI-X | Flutter | React Native |
|------|---------|---------|--------------|
| **对我们的适配成本** | 🟢 **极低**（代码不用改） | 🔴 高（需用 Dart 重写 UI） | 🟡 中（TS 可复用逻辑，UI 需改写） |
| **HarmonyOS 原生支持** | 🟢 **最佳** | 🟡 需适配层 | 🔴 社区适配，不稳定 |
| **Android/iOS 性能** | 🟢 接近原生 | 🟢 接近原生 | 🟡 有 Bridge 开销 |
| **桌面/Web 支持** | 🔴 无 | 🟢 全平台 | 🟡 需第三方 |
| **生态丰富度** | 🟡 成长中 | 🟢 丰富 | 🟢 丰富 |
| **开发者数量** | 🟡 主要在中国 | 🟢 全球 | 🟢 全球 |

### 6.2 推荐方案

**对于我们的数独项目，ArkUI-X 是最优选择：**

1. ✅ **零改造成本**：现有 ArkTS 代码直接复用，不需要学新语言
2. ✅ **三端一致**：HarmonyOS + Android + iOS 一套代码
3. ✅ **鸿蒙原生最优**：保持 HarmonyOS 端的最佳体验
4. ⚠️ **唯一不足**：如果未来需要 macOS/Web 版本，需要考虑 Flutter

---

## 七、macOS/桌面端的替代方案

如果确实需要 macOS 桌面版数独，可考虑以下方案：

| 方案 | 说明 | 工作量 |
|------|------|--------|
| **Flutter 重写 UI** | Dart 重写，支持全平台 | 🔴 大（需重写 UI 层） |
| **Electron + Web** | 把逻辑导出为 TS 库，套 Web 壳 | 🟡 中（需写 Web UI） |
| **等 ArkUI-X 桌面端** | 官方 roadmap 中有计划，但无时间表 | ✅ 零（等就行） |
| **Swift/Kotlin Multiplatform** | 各平台原生开发 | 🔴 大 |

---

## 八、实施建议

如果决定推进 ArkUI-X 跨平台部署，建议分步进行：

### Phase 1：环境验证（1-2 天）

- [ ] 安装 ArkUI-X SDK 和 ACE Tools
- [ ] 运行 `ace check` 验证环境完整性
- [ ] 在现有工程中初始化跨平台支持（`ace create --type crossplatform`）
- [ ] 编译一次 Android APK，确认基础流程通

### Phase 2：Android 适配（3-5 天）

- [ ] 编译并在 Android 设备上运行数独 App
- [ ] 验证 UI 渲染一致性（9×9 网格、手势键盘、动画）
- [ ] 验证本地存储（游戏存档、设置）
- [ ] 验证 Worker 线程（数独求解器）
- [ ] 适配 Android 特定的权限和生命周期

### Phase 3：iOS 适配（3-5 天）

- [ ] 在 macOS 上配置 Xcode 环境
- [ ] 编译并在 iOS 设备/模拟器上运行
- [ ] 验证 UI 和功能一致性
- [ ] 处理 iOS 特定的适配（安全区域、状态栏等）

### Phase 4：平台专属能力桥接（按需）

- [ ] 为 Android/iOS 实现 OCR 替代方案（如需要）
- [ ] 为 Android/iOS 实现 AI 教练替代方案（如需要）
- [ ] CI/CD 配置多平台构建流水线

---

## 九、参考资料

- [ArkUI-X 官方文档 (Gitee)](https://gitee.com/arkui-x/docs)
- [ArkUI-X GitHub](https://github.com/arkui-x)
- [ArkUI-X 5.0.4 Release Notes](https://cloud.tencent.com/developer/article/2514737)
- [ArkUI-X 组件跨平台支持列表](https://gitcode.com/arkui-x/docs/blob/master/zh-cn/application-dev/reference/arkui-ts/README.md)
- [ArkUI-X 跨平台开发实践指南 (CSDN)](https://blog.csdn.net/2403_89081261/article/details/148430446)
- [ArkUI-X 跨平台技术探索 (七猫)](https://tech.qimao.com/hua-wei-arkui-xkua-ping-tai-ji-zhu-tan-suo/)
- [ArkUI-X vs Flutter 深度对比](https://www.cnblogs.com/developer-laoliu/articles/19452719)
- [鸿蒙 ArkUI-X 跨平台路漫漫其修远兮](https://developer.huawei.com/consumer/cn/blog/topic/03175193539859095)
