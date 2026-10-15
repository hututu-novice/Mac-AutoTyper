# AutoTyper · 夸克浏览器逐字符输入工具

本项目包含独立的 macOS 和 Windows 实现。它可用于夸克中的普通网页文本框，网址没有限定为批改网；当前代码仍只适配夸克浏览器，Chrome、Edge、Safari 等浏览器尚未适配。程序向用户选定的页面、当前获得焦点的可编辑文本框发送逐字符键盘事件；不会粘贴原文、改写网页 DOM、自动打开网站或提交表单。网页编辑器能否接收并保留全部字符，需要在目标页面实际验证。

| 平台版本 | 架构与系统 | 当前验收状态 | 下载 |
| --- | --- | --- | --- |
| Mac Intel | `x86_64`，macOS 13+ | Intel Mac 上夸克本地页逐字输入已验收 | [下载 Intel 版](https://github.com/hututu-novice/Mac-AutoTyper/releases/latest/download/Mac-AutoTyper-macOS-Intel-x86_64.zip) |
| Mac Apple Silicon | `arm64`，macOS 13+ | 已从源码交叉编译、打包并签名；M 系列实机启动和夸克输入未验收，理论上可运行，需 M 系列用户实机确认 | [下载 Apple Silicon 版](https://github.com/hututu-novice/Mac-AutoTyper/releases/latest/download/Mac-AutoTyper-macOS-Apple-Silicon-arm64.zip) |
| Windows | Windows 10/11 `x64` | 用户确认 Windows 版已在夸克中跑通；本仓库未保存完整的 Windows 实机测试记录 | [下载 Windows x64 版](https://github.com/hututu-novice/Mac-AutoTyper/releases/latest/download/Windows-AutoTyper-win-x64.zip) |

Intel 和 Apple Silicon 使用分别构建的 `.app` 下载包；请根据芯片选择对应版本。Apple Silicon 版目前有 ARM64 编译、打包和签名证据，但没有 M 系列实机验收证据。Windows 的实机跑通状态由用户确认，详细环境和逐项结果尚未归档。所有网页编辑器仍需在目标页面实际检查输入结果。

第一次使用请阅读 [中文详细使用教程](docs/使用教程.md)：包含启动位置、逐个按钮说明、本地练习、批改网操作顺序、暂停停止、常见问题和交付文件介绍。

## 运行环境与构建

- macOS 13.0 或更高版本；Intel 版为 `x86_64`，Apple Silicon 版为 `arm64`。Intel 版已在 macOS 13.7.8、Swift 5.8.1、夸克 7.4.0.1013 上构建和测试。
- 无需完整 Xcode。使用 Xcode Command Line Tools：`./build.sh`。
- 双击对应下载包中的 `Mac-AutoTyper.app` 启动；应用使用临时签名，首次打开可能需要在“系统设置 → 隐私与安全性”允许打开。
- 运行 `./build-release-assets.sh` 可生成 Intel、Apple Silicon 和 Windows 三个发布 ZIP 与 SHA-256 校验文件。若本地没有 Windows x64 EXE，脚本会调用 `./windows/build.sh`，需要 Zig 0.17.0；Mac ARM64 包在 Intel 主机交叉编译，不能替代 M 系列实机验收。
- 如需放入当前用户的应用目录，可运行 `ditto Mac-AutoTyper.app ~/Applications/Mac-AutoTyper.app`；重新构建后需要重新复制。构建会改变临时签名，可能需要重新授予辅助功能权限。
- 运行 `./test.sh` 可执行不依赖图形授权的模型与目标策略测试。

## 首次授权

在“系统设置 → 隐私与安全性 → 辅助功能”中允许 **Mac AutoTyper**，应用才能核验网页编辑焦点并发出键盘事件。macOS 也可能请求允许本应用自动化控制夸克，以读取窗口、标签页、标题和 URL。拒绝任何必需授权时，应用应显示错误并停止，不会输入。授权后建议退出并重开应用。

当前构建使用临时签名。重新构建或替换 App 后，系统可能保留旧的辅助功能条目且开关仍显示开启，但新构建实际未获授权。此时在辅助功能列表中选中旧的 **Mac-AutoTyper** 条目并点 `−` 移除，再点 `+` 添加实际运行的 `~/Applications/Mac-AutoTyper.app`，确认开关开启，然后退出并重新打开 App。仅切换旧条目的开关可能无法恢复。重新授权前先保存编辑框中的文字，因为退出 App 不会自动保存原文。

## 使用

1. 在夸克中自行打开目标网页并准备好文本框；本应用不会替你打开网站。可先使用 [本地验收页](tests/quark-acceptance.html)。
2. 在应用的大文本框粘贴或输入原文，或导入 UTF-8 TXT。导入不会主动更改原文；无法保证原样的控制字符会在开始前报错。界面的“词数”按空白分隔统计，中文连续文本可视为一个词。
3. 调整每字符毫秒或等效 WPM（按每词 5 字符换算），设定固定间隔或 0–20% 轻度变化及 0–30 秒倒计时。界面显示基础间隔的估算；实际耗时还包括逐字目标核验，可能更长。设置保存在 `~/Library/Application Support/Mac-AutoTyper/settings.json`。
4. 点击“刷新夸克窗口/标签”，选择目标并核对标题、URL。每次开始都需确认该页面不是支付页。
5. 倒计时内切换到夸克的选定标签，点击可编辑文本框。程序在开始时核验所选窗口与标签页，逐字符核验前台应用及同一个辅助功能网页、窗口、标题、URL 和编辑焦点。任何核验失败都会停止。
6. 使用应用中的“暂停”“继续”“取消/立即停止”。切回本应用会自动暂停；点击“继续”后有 3 秒切回原文本框。可选全局停止热键 `⌃⌥S`、`⌃⇧S` 或关闭；注册的是指定热键，不监听或记录日常按键。

界面环形图显示当前输入任务的完成百分比、已输入字符和剩余字符。图表样式参考了 GitHub 上的 [SwiftUICharts](https://github.com/willdale/SwiftUICharts)；项目使用 AppKit 原生绘制，没有复制该项目代码或增加第三方依赖。

多行文本仅允许向可核验的多行文本框输入。保存/读取文本模板使用本地 TXT 文件。应用不会读取 Cookie 或凭据，也没有联网传输逻辑。

## 安全边界

支付页通过标题和 URL 的常见标记拦截；密码框通过辅助功能角色拒绝；系统对话框和非夸克前台窗口会被拒绝。网页可以在标题、URL 不变时自行改变内容，页面脚本也可能在键盘事件后触发额外行为，所以这些识别无法绝对保证。只在可信页面、可见且可核验的目标文本框使用，并在输入后核对实际内容。应用本身不主动提交表单。

## 当前验收状态

Intel 版 T01–T12 在夸克本地页已有实测记录；Apple Silicon 版已从源码交叉编译并打包，尚无 M 系列实机运行记录；Windows 版由用户确认已在夸克中跑通，详细结果尚未归档。测试边界见 [测试结果](docs/TEST-RESULTS.md)。

Windows 版源码与构建入口位于 `windows/`。`./windows/build.sh` 需要 Zig 0.17.0，生成 `dist/windows/Windows-AutoTyper.exe`；打包和安装方法见 [Windows 说明](windows/README-Windows.txt)。目前代码只适配夸克；其他浏览器和具体网站编辑器仍需各自验证。

## 来源与许可

基于 [bunnysayzz/Mac-Autotype](https://github.com/bunnysayzz/Mac-Autotype) 的 `903c4686d2478aa944c23c7ac8b688a0d0b3b36c`（MIT）。保留原作者 [LICENSE](LICENSE)；本项目复用了入口、菜单与 `swiftc` 打包思路，重新实现输入、目标核验、中文 GUI 和应用图标。图标可通过 `swift resources/make-icon.swift resources/icon.icns` 重新生成。详见 [第三方清单](THIRD-PARTY.md)。
