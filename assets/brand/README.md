# 不错的数独 / Not Bad Sudoku 图标

图标以微微倾斜的米白纸面棋盘为主体，连续细线、衬线数字与青绿选中格呼应官网。它不包含中英文产品名；改变应用名称不会改变图形。棋盘几何直接用 SVG 绘制，四个数字以系统 Georgia 字体轮廓转为路径，不包含或加载字体文件，不依赖第三方插画或模板图片。

- 主色：墨绿 `#153E39`
- 格子：米白 `#FFFEF8`
- 选中格：青绿 `#16796F`；同一行浅绿 `#E1ECD9`；细线 `#789486`
- 画布：1024×1024；纸面768×768，内部棋盘704×704，纸边32；旋转角度−3°。
- 官网、应用内标识与启动图保留纸面外的透明区域；桌面分层背景及商店图标使用铺满画布的极浅灰绿 `#E8EEE6` 纯色。
- 浮起阴影：GaussianBlur 14、向下偏移24、不透明度0.28；阴影与纸面保留在透明前景层中。官网SVG采用 `viewBox="64 64 896 896"` 收紧展示留白，不改变应用资源的1024×1024画布。

资源：

| 文件 | 用途 |
| --- | --- |
| `sudoku-icon.svg` | 纸面外透明的矢量艺术稿，官网可以直接引用或复制 |
| `sudoku-mark-1024.png` | 1024×1024透明标识，用于官网、应用内等场景 |
| `sudoku-icon-1024.png` | 1024×1024极浅灰绿底商店图标，与工程中的前景、背景PNG合成结果逐像素一致 |
| `sudoku-foreground.svg` | 透明前景源文件 |
| `sudoku-background.svg` | 铺满画布、无透明像素的极浅灰绿背景源文件 |
| `render-icons.cjs` | 可复现的SVG渲染和一致性验证脚本 |

已同步：

- `AppScope/resources/base/media/{foreground,background}.png`：1024×1024。
- `entry/src/main/resources/base/media/{foreground,background}.png`：1024×1024。
- `entry/src/main/resources/base/media/startIcon.png`：144×144，纸面外透明。

华为官方[应用图标配置与开发](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-app-icon-configuration)要求分层前景采用透明PNG、背景为纯色且不能含透明像素，并要求商店上传图标与软件包图标一致。因此透明艺术稿与发行图标分别导出，商店使用极浅灰绿底合成版本。

官方[应用图标资源规范](https://developer.huawei.com/consumer/cn/doc/design-guides/application-icon-0000001953444009)要求1024×1024正方形分层PNG，由系统按场景生成遮罩，资源不自行裁切圆角。圆形mask只对核心棋盘做几何核验，不保证纸面外角与阴影在所有系统遮罩下完整保留；它不是真机桌面或系统遮罩效果验证，也不表示所有主题和动效都已测试。构建工具可能缩放或优化PNG，源码图层与商店图标的逐像素一致不代表最终包内PNG字节相同。

两处 `layered_image.json` 与AppScope、EntryAbility、启动窗口配置保持原引用名称，因此无需修改manifest。ArkUI-X Android清单另引用 `@mipmap/ic_launcher`，iOS仅有空AppIcon资源描述；本次不新增非鸿蒙平台的图标包。

复现命令（仓库根目录）：

```sh
node assets/brand/render-icons.cjs
```

使用已有sharp及其SVG渲染器。本机版本：sharp 0.35.5、librsvg 2.63.2。首次将系统 Georgia 数字转为路径时使用临时 uv 环境中的 fontTools；已提交的 SVG 路径不依赖此环境，常规重渲染只需 sharp。若自动查找不到已有sharp，可设置 `SUDOKU_SHARP=/absolute/path/to/sharp`。脚本从SVG源文件重新渲染；不读取或修改旧图案。商店PNG由新生成的前景和背景图层合成，以避免不同抗锯齿合成方式造成像素差异。

这些文件是图标素材，不是游戏界面截图。
