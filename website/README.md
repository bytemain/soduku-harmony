# 不错的数独 / Not Bad Sudoku 官网

更新：2026-11-02。纯 HTML/CSS/JavaScript，无构建依赖。用户已确认 `support@oranix.cn` 开通，中英文支持/隐私页已启用 `mailto:`，本次没有代发邮件。

最终中文名 **不错的数独**、英文名 **Not Bad Sudoku** 已发布到 <https://sudoku.oranix.cn/>。中文首页、隐私与支持页和英文 3 页均已核验。官网 Logo 与 App 前景使用透明外背景，保留米白棋盘、数字与阴影；当前纸面768×768、内部棋盘704×704、纸边32，旋转−3°；GaussianBlur 14、向下偏移24、不透明度0.28的软阴影增强浮起效果。官网SVG使用 `viewBox="64 64 896 896"` 收紧展示留白。App桌面分层背景独立采用极浅灰绿 `#E8EEE6` 纯色，官网艺术稿与启动图仍透明；网站布局、配色、公司主体、域名和邮箱不变。

官网已通过 **GitHub Pages 自定义域名 HTTPS 上线**：发布提交 `58337cb8591301af04f15aaab55f556c3c661342`，来源 `gh-pages /`，对应构建状态 `built`、`https_enforced=true`；证书已 `approved`，当前到期日期为 `2027-01-31`。使用 Google HTTPS DNS 返回的真实 IP 配合 `curl --resolve`，保留正常证书校验，最终 6 页和 3 个资源全部 HTTP 200、SHA-256 与本地一致；中文与英文名称分别核验通过，新图标内容一致。旧 github.io 首页及隐私地址均 301 到对应自定义地址，普通本机访问也已成功。完整记录见 `website/deployment-verification.json`。网站发布只含静态白名单及保留的 CNAME，未包含游戏代码、签名材料、审计文件或 APP 包。

## 发布地址

| 页面 | GitHub Project Pages 旧地址 | 已验证 HTTPS 的正式地址 |
| --- | --- | --- |
| 中文首页 | `https://bytemain.github.io/soduku-harmony/` | `https://sudoku.oranix.cn/` |
| 英文首页 | `https://bytemain.github.io/soduku-harmony/en/` | `https://sudoku.oranix.cn/en/` |
| 中文隐私 | `https://bytemain.github.io/soduku-harmony/privacy/` | `https://sudoku.oranix.cn/privacy/` |
| 英文隐私 | `https://bytemain.github.io/soduku-harmony/en/privacy/` | `https://sudoku.oranix.cn/en/privacy/` |
| 中文支持 | `https://bytemain.github.io/soduku-harmony/support/` | `https://sudoku.oranix.cn/support/` |
| 英文支持 | `https://bytemain.github.io/soduku-harmony/en/support/` | `https://sudoku.oranix.cn/en/support/` |

所有站内导航与 CSS/JS/SVG 引用均为相对路径，两种地址无需修改页面。`sudoku.oranix.cn` 已绑定 Pages，Google 与 Cloudflare HTTPS DNS 均确认 CNAME 指向 `bytemain.github.io.`，TTL 600 秒；自定义 HTTPS 证书与最终内容核验已通过。初次发布未放 `CNAME`，后续发布脚本会保留 Pages 生成的 `CNAME`。页面可直接编辑，无需 npm。官网图标为透明外背景、768纸面/704棋盘/32纸边、软阴影浮起的倾斜米白细线设计；网页棋盘明确标记“规则示意，非应用截图”。

## 只发布静态 dist 的命令

在仓库根目录运行：

```sh
python3 website/deploy/validate-site.py
python3 website/deploy/publish-gh-pages.py
```

第二条默认 **dry-run**，只校验并显示将发布的文件，没有 commit/push。检查完成后，由负责发布的操作者运行：

```sh
python3 website/deploy/publish-gh-pages.py --publish
```

该脚本只允许以下 10 个文件：6 个 HTML、`assets/site.css`、`assets/site.js`、`assets/icon.svg`、`.nojekyll`。如果 dist 出现额外文件或软链接，立即失败。它在临时隔离 checkout 中新建或更新 `gh-pages` 分支，采用已核实账号的 GitHub noreply 提交邮箱；**不 checkout 当前工作区、不暂存游戏修改、不提交 main、不读取或复制仓库外签名资料**。只有上述静态文件进入提交；README、部署脚本、校验报告、`docs/`、`release-artifacts/` 和所有应用代码均不发布。

脚本仅接受现有 origin `bytemain/soduku-harmony`；需要现有 GitHub/Git 鉴权，脚本不创建凭据。已有 `gh-pages` 时保留其历史，使用正常 fast-forward push，不 force push。以后通过 GitHub 设置加入的 `CNAME=sudoku.oranix.cn` 会被保留；遇到其他自定义域名则停止供操作者核对。

本次已在仓库 **Settings → Pages** 配置 **Deploy from a branch → gh-pages → /(root)** 并验证部署成功。以后更新时，推送成功只表示静态分支已上传，仍需等待 Pages 构建完成，再访问上述 6 个页面核验 HTTPS、内容和资源。脚本不代改 Pages 设置，也不创建新仓库。[GitHub 官方发布源说明](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)

正式中文隐私地址为 `https://sudoku.oranix.cn/privacy/`，已通过 HTTPS 与内容核验。此前填入华为正式版本草稿的 `https://bytemain.github.io/soduku-harmony/privacy/` 已验证 301 到正式地址；后台最终 URL 的回填与保存由主任务确认。不要填本地预览地址。

## GitHub Pages 隐私说明

中英文政策已移除发布前草稿/邮箱未启用文字，并区分离线应用与网站托管。网页代码不提供账号、广告、分析服务或追踪 Cookie；GitHub Pages 为安全目的记录访客 IP。GitHub 的数据处理地点和保留时间按其隐私声明执行，**没有承诺固定日志保留天数**。政策正文直接链接官方说明。[Pages 数据收集](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages#data-collection)、[GitHub 隐私声明](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement)

页面外链只有上述官方隐私资料和已开通的支持邮箱，不加载远程字体、图片或脚本。应用仍保持本地进度、用户主动剪贴板、默认关闭的握持感知及系统备份披露；GitHub 网站日志不应误填成应用内业务上报。

## sudoku.oranix.cn 配置进度

DNS 已通过 [dnscontrol-gitops PR #1](https://github.com/oranix-io/dnscontrol-gitops/pull/1) 合并，提交 `ec24b7b236675173e6f4d78bd146dfcc0fd4916b`。[master 自动应用任务 41408817138](https://github.com/oranix-io/dnscontrol-gitops/actions/runs/41408817138) 成功，实际仅新增 `sudoku.oranix.cn CNAME bytemain.github.io.`，TTL 600 秒。Google 和 Cloudflare 的 HTTPS DNS 查询均已确认生效。本地普通 DNS 曾仍返回旧的 NXDOMAIN，不能据此否定公开 DNS 的新状态。

早期检查中曾等待证书签发、本机系统 DNS 曾返回旧记录；最终检查已确认 `approved`、强制 HTTPS、9 项内容一致和旧首页/隐私 URL 跳转正确。本轮普通本机 curl 也返回成功（退出码 0），系统 DNS 限制已解除；逐项内容核验仍使用公开 HTTPS DNS 的真实 A 记录并保留正常 TLS 校验。此结果仅说明本工作站验证成功，**不代表已验证中国大陆或所有地区的可达性**。

配置流程保留如下，本次 Pages 绑定、DNS 添加、HTTPS 开启及内容核验均已完成：

1. 先按 GitHub 官方说明验证域名控制权。
2. 在此仓库 Pages 的 Custom domain 设置 `sudoku.oranix.cn`。分支发布方式会在 `gh-pages` 根目录产生 `CNAME`；后续脚本会保留它。
3. 在 DNS 添加主机 `sudoku` 的 CNAME，目标为 **`bytemain.github.io`**，不含 `/soduku-harmony` 路径。避免设置冲突记录。
4. DNS 与证书就绪后启用 Enforce HTTPS，并核验 6 页、资源和默认域名跳转；后台使用验证过的正式地址。

GitHub 建议先完成 Pages 绑定，再配置 DNS，本次已按此顺序完成。具体流程和 HTTPS 等待行为以[GitHub 自定义域名官方说明](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site)为准。DNS 由独立 GitOps 仓库执行，本静态发布脚本不修改 DNS。域名/企业相关备案信息仍应按实际适用要求核实，网页没有编造任何备案号码。

`deploy/nginx.conf.example` 保留为未来自建静态托管备选，当前 GitHub Pages 不使用它。若更换主机，需先同步隐私政策中的托管服务与日志事实。

## 验证与预览

`pages-preflight.json` 保存本轮结果：6 个页面、10 个公开文件；项目路径与自定义根域下的 82 个站内资源/链接均有效，10 个外链均属于官方隐私资料或支持邮箱；页面标题、语言、图片 alt、锚点检查通过。JS 语法检查和发布脚本 dry-run 已通过。

早先版本已有桌面和 390×844 手机尺寸浏览器 QA；`deployment-verification.json` 已刷新为当前中文名、英文名与768纸面/704棋盘软阴影图标版本，包含发布提交、对应 Pages 构建、解析 IP、证书状态、9 项 SHA-256、分语言品牌检查、旧地址跳转和普通本机访问成功结果。网络核验不等同于全部浏览器交互验收，最终截图由主任务另行更新。邮件地址由用户确认已开通，本次未发送测试邮件。

本地预览（在 website 目录）：

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory dist
```

## 应用上线后的改动

应用尚无正式公开商店下载链接，首页保留“即将上线”禁用按钮。获得实际官方商店链接后再替换按钮并更新支持页，不猜测下载 URL。若应用新增联网、账号、支付、广告或分析服务，必须同步隐私说明。

## 部署包

`oranix-sudoku-website.zip` 包含 `dist/`、README 和 `deploy/`，用于交付和审查；**gh-pages 脚本只发布 dist 白名单文件，不上传整个 ZIP**。ZIP 不包含应用代码、APP、日志、证书、私钥、密码或账户令牌。修改后重新打包，避免部署旧稿。
