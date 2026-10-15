Windows AutoTyper 1.0.2 · 夸克专用

状态：Windows x64 版已在 Windows 实机的夸克中跑通。GitHub 源码仓库与发布 ZIP 分开维护。

系统要求：Windows 10/11 x64，已安装 Windows 版夸克浏览器。

若取得另行提供的 ZIP 安装包：先退出正在运行的旧版，解压整个 ZIP，双击 install.cmd。安装到当前用户的
%LOCALAPPDATA%\Windows-AutoTyper，不需要管理员权限；开始菜单中会出现 Windows AutoTyper。
也可不安装，直接运行 Windows-AutoTyper.exe。

从源码构建：在装有 Zig 0.17.0 的构建环境运行项目根目录的 ./windows/build.sh，输出到 dist/windows/。本说明记录的 Windows 实机跑通状态由用户确认；构建成功本身不代替 GUI 验收。要自行制作 ZIP，可将生成的 EXE 与本目录的 install.cmd、install.ps1、README-Windows.txt 以及 tests/quark-acceptance.html 一起压缩；ZIP 内文件需放在同一目录层级。

使用：
1. 在夸克中自行打开目标网页；建议先打开包内 quark-acceptance.html 做本地练习。
2. 在应用中输入原文，或导入 UTF-8 TXT。设置每字符毫秒（20–2000）和倒计时（3–30 秒）。
3. 点击“刷新夸克窗口/标签”，从列表中选择目标，核对标题和完整 URL。列表读取每个夸克窗口当前打开的标签；若要选择同一窗口的其他标签，请先在夸克中切换，再回到应用刷新。若 UI Automation 无法直接读取地址栏，刷新会短暂切到夸克并用 Ctrl+L 读取网址；必要时临时复制地址并恢复原剪贴板。此操作不会粘贴原文。
4. 点击“开始”并核对确认框中的标题和 URL。倒计时内切到选定的夸克窗口，点击目标网页中的普通文本编辑框。
5. 程序需从 Windows UI Automation 读到前台夸克窗口、网页文档和编辑焦点。若地址栏在输入时可读，会核对它与刷新时选中的 URL；否则沿用刷新时捕获并由你确认的 URL，逐字符锁定同一窗口、网页文档、标题和输入焦点。任何必需核验失败都会停止。
6. 切回控制窗口会自动暂停；点击“继续”后有 3 秒切回原文本框。可用 Ctrl+Alt+S 全局停止，或点“立即停止”。

注意：不支持密码框；含换行的原文只会输入到可通过 UI Automation 核验为多行的文本框；标题或 URL 含常见支付标记时拒绝输入；仅接受 http、https、file URL。程序不主动提交表单，不读取 Cookie，不联网传输原文，不使用剪贴板发送原文。刷新网址时若使用复制回退，会尝试恢复原剪贴板；若恢复失败，界面会明确报错，请自行检查剪贴板。每个网页编辑器仍可能有差异，输入结束后请核对网页实际内容。

卸载：删除 %LOCALAPPDATA%\Windows-AutoTyper 文件夹及开始菜单里的 Windows AutoTyper 快捷方式。
