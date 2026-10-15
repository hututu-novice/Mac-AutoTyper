import AppKit
import UniformTypeIdentifiers

final class ContentViewController: NSViewController, NSTextViewDelegate, NSTextFieldDelegate {
    private let engine = TypingEngine()
    private let inspector = QuarkInspector()
    private var settings = SavedSettings.load()
    private var targets: [QuarkTarget] = []
    private let textView = NSTextView()
    private let counts = NSTextField(labelWithString: "字符 0 · 词数 0")
    private let estimate = NSTextField(labelWithString: "基础间隔约 0 秒 + 目标核验")
    private let msSlider = NSSlider(value: 100, minValue: 20, maxValue: 2000, target: nil, action: nil)
    private let msField = NSTextField(string: "100")
    private let wpmSlider = NSSlider(value: 120, minValue: 6, maxValue: 600, target: nil, action: nil)
    private let wpmField = NSTextField(string: "120")
    private let jitterSlider = NSSlider(value: 0, minValue: 0, maxValue: 20, target: nil, action: nil)
    private let jitterField = NSTextField(string: "0")
    private let countdownField = NSTextField(string: "5")
    private let hotkeyMenu = NSPopUpButton()
    private let targetMenu = NSPopUpButton()
    private let targetDetail = NSTextField(wrappingLabelWithString: "请刷新并选择夸克窗口/标签页")
    private let startButton = NSButton(title: "开始", target: nil, action: nil)
    private let pauseButton = NSButton(title: "暂停", target: nil, action: nil)
    private let stopButton = NSButton(title: "取消/立即停止", target: nil, action: nil)
    private let status = NSTextField(wrappingLabelWithString: "就绪")
    private let progress = NSProgressIndicator()
    private let progressRing = ProgressRingView()
    private let progressCaption = NSTextField(labelWithString: "等待开始")
    private let remainingCaption = NSTextField(labelWithString: "剩余 0 字符")
    private var lastDone = 0
    private var lastTotal = 0

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 780, height: 900))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        bindEngine()
        restoreSettings()
        refreshCounts()
    }

    private func label(_ value: String) -> NSTextField {
        let result = NSTextField(labelWithString: value)
        result.font = .systemFont(ofSize: 13)
        return result
    }
    private func row(_ items: [NSView]) -> NSStackView {
        let stack = NSStackView(views: items)
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
    }
    private func button(_ title: String, _ action: Selector) -> NSButton {
        let value = NSButton(title: title, target: self, action: action)
        value.bezelStyle = .rounded
        return value
    }

    private func buildUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 10
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            root.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -18)
        ])
        let title = label("Mac AutoTyper · 夸克专用")
        title.font = .boldSystemFont(ofSize: 20)
        root.addArrangedSubview(title)
        let hint = label("逐字符键盘事件；只向选定的夸克标签页中已聚焦的可编辑文本框输入。")
        root.addArrangedSubview(hint)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        textView.frame = NSRect(x: 0, y: 0, width: 740, height: 225)
        textView.minSize = NSSize(width: 0, height: 225)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 740, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        scroll.documentView = textView
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.delegate = self
        textView.font = .systemFont(ofSize: 14)
        root.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 225).isActive = true
        let importButton = button("导入 UTF-8 TXT", #selector(importText))
        let saveTemplate = button("保存文本模板", #selector(saveText))
        let loadTemplate = button("读取文本模板", #selector(importText))
        root.addArrangedSubview(row([importButton, saveTemplate, loadTemplate]))
        root.addArrangedSubview(row([counts, estimate]))

        let dashboard = NSView()
        dashboard.wantsLayer = true
        dashboard.layer?.cornerRadius = 16
        dashboard.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        dashboard.layer?.borderColor = NSColor.separatorColor.cgColor
        dashboard.layer?.borderWidth = 1
        root.addArrangedSubview(dashboard)
        dashboard.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        dashboard.heightAnchor.constraint(equalToConstant: 132).isActive = true
        dashboard.addSubview(progressRing)
        progressRing.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            progressRing.leadingAnchor.constraint(equalTo: dashboard.leadingAnchor, constant: 24),
            progressRing.centerYAnchor.constraint(equalTo: dashboard.centerYAnchor),
            progressRing.widthAnchor.constraint(equalToConstant: 94),
            progressRing.heightAnchor.constraint(equalToConstant: 94)
        ])
        let heading = label("输入进度")
        heading.font = .boldSystemFont(ofSize: 16)
        let captionStack = NSStackView(views: [heading, progressCaption, remainingCaption])
        captionStack.orientation = .vertical
        captionStack.alignment = .leading
        captionStack.spacing = 7
        captionStack.translatesAutoresizingMaskIntoConstraints = false
        dashboard.addSubview(captionStack)
        NSLayoutConstraint.activate([
            captionStack.leadingAnchor.constraint(equalTo: progressRing.trailingAnchor, constant: 24),
            captionStack.centerYAnchor.constraint(equalTo: dashboard.centerYAnchor),
            captionStack.trailingAnchor.constraint(lessThanOrEqualTo: dashboard.trailingAnchor, constant: -20)
        ])
        progressCaption.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        remainingCaption.textColor = .secondaryLabelColor

        msSlider.target = self; msSlider.action = #selector(msChanged)
        wpmSlider.target = self; wpmSlider.action = #selector(wpmChanged)
        jitterSlider.target = self; jitterSlider.action = #selector(jitterChanged)
        for field in [msField, wpmField, jitterField, countdownField] {
            field.delegate = self
            field.alignment = .right
            field.widthAnchor.constraint(equalToConstant: 55).isActive = true
        }
        msSlider.widthAnchor.constraint(equalToConstant: 245).isActive = true
        wpmSlider.widthAnchor.constraint(equalToConstant: 245).isActive = true
        jitterSlider.widthAnchor.constraint(equalToConstant: 245).isActive = true
        root.addArrangedSubview(row([label("每字符毫秒"), msSlider, msField, label("ms")]))
        root.addArrangedSubview(row([label("等效 WPM"), wpmSlider, wpmField, label("词/分（按 5 字符）")]))
        root.addArrangedSubview(row([label("间隔变化"), jitterSlider, jitterField, label("%；0 = 固定")]))
        hotkeyMenu.addItems(withTitles: ["⌃⌥S：停止", "⌃⇧S：停止", "关闭全局热键"])
        hotkeyMenu.target = self; hotkeyMenu.action = #selector(settingsChanged)
        root.addArrangedSubview(row([label("启动倒计时"), countdownField, label("秒（0–30）"), label("全局热键"), hotkeyMenu]))

        let refresh = button("刷新夸克窗口/标签", #selector(refreshTargets))
        targetMenu.target = self; targetMenu.action = #selector(targetChanged)
        targetMenu.widthAnchor.constraint(lessThanOrEqualToConstant: 475).isActive = true
        root.addArrangedSubview(row([refresh, targetMenu]))
        targetDetail.lineBreakMode = .byWordWrapping
        targetDetail.maximumNumberOfLines = 2
        root.addArrangedSubview(targetDetail)
        targetDetail.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        startButton.target = self; startButton.action = #selector(start)
        pauseButton.target = self; pauseButton.action = #selector(pause)
        stopButton.target = self; stopButton.action = #selector(stop)
        pauseButton.isEnabled = false; stopButton.isEnabled = false
        root.addArrangedSubview(row([startButton, pauseButton, stopButton]))
        progress.minValue = 0; progress.maxValue = 1; progress.doubleValue = 0
        progress.isIndeterminate = false
        root.addArrangedSubview(progress)
        progress.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        root.addArrangedSubview(status)
        status.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        refreshTargets()
    }

    private func bindEngine() {
        engine.onUpdate = { [weak self] state, done, total, elapsed, message in
            guard let self = self else { return }
            if done >= 0 { self.lastDone = done }
            if total >= 0 { self.lastTotal = total }
            self.progress.maxValue = Double(max(self.lastTotal, 1))
            self.progress.doubleValue = Double(self.lastDone)
            self.updateDashboard()
            let active = [.countdown, .typing, .paused].contains(state)
            self.startButton.isEnabled = !active
            self.stopButton.isEnabled = active
            self.pauseButton.isEnabled = [.typing, .paused].contains(state)
            self.pauseButton.title = state == .paused ? "继续" : "暂停"
            self.status.stringValue = "\(state.rawValue) · \(self.lastDone)/\(self.lastTotal) 字符 · 已用 \(Int(elapsed)) 秒 · \(message)"
        }
    }

    private func restoreSettings() {
        msSlider.integerValue = settings.milliseconds
        msField.integerValue = settings.milliseconds
        wpmSlider.integerValue = Int((60_000.0 / Double(settings.milliseconds) / 5).rounded())
        wpmField.integerValue = wpmSlider.integerValue
        jitterSlider.integerValue = settings.variationPercent
        jitterField.integerValue = settings.variationPercent
        countdownField.integerValue = settings.countdown
        hotkeyMenu.selectItem(at: max(0, min(2, settings.hotkey)))
    }

    private func refreshCounts() {
        let value = textView.string
        counts.stringValue = "字符 \(value.count) · 词数 \(value.split(whereSeparator: { $0.isWhitespace }).count)"
        estimate.stringValue = String(format: "基础间隔约 %.1f 秒 + 目标核验", Double(value.count * settings.milliseconds) / 1000)
        updateDashboard()
    }
    private func updateDashboard() {
        let total = lastTotal > 0 ? lastTotal : textView.string.count
        let done = min(lastDone, total)
        progressRing.fraction = total > 0 ? CGFloat(done) / CGFloat(total) : 0
        progressCaption.stringValue = "\(done) / \(total) 字符"
        remainingCaption.stringValue = "剩余 \(max(total - done, 0)) 字符"
    }
    func textDidChange(_ notification: Notification) {
        if !engine.isBusy { lastDone = 0; lastTotal = 0 }
        refreshCounts()
    }
    func controlTextDidEndEditing(_ notification: Notification) {
        if let field = notification.object as? NSTextField, field === wpmField {
            let wpm = max(6, min(600, wpmField.integerValue))
            settings.milliseconds = max(20, min(2000, Int((12_000.0 / Double(wpm)).rounded())))
            restoreSettings()
            saveSettings()
        } else { settingsChanged() }
    }

    @objc private func msChanged() { msField.integerValue = msSlider.integerValue; settingsChanged() }
    @objc private func wpmChanged() { wpmField.integerValue = wpmSlider.integerValue; settings.milliseconds = max(20, min(2000, Int((12_000.0 / Double(wpmSlider.integerValue)).rounded()))); restoreSettings(); saveSettings() }
    @objc private func jitterChanged() { jitterField.integerValue = jitterSlider.integerValue; settingsChanged() }
    @objc private func settingsChanged() {
        settings.milliseconds = max(20, min(2000, msField.integerValue))
        settings.variationPercent = max(0, min(20, jitterField.integerValue))
        settings.countdown = max(0, min(30, countdownField.integerValue))
        settings.hotkey = hotkeyMenu.indexOfSelectedItem
        restoreSettings()
        saveSettings()
        (NSApp.delegate as? AppDelegate)?.configureHotkey(settings.hotkey)
    }
    private func saveSettings() {
        do { try settings.save() } catch { showError("保存配置失败：\(error)") }
        refreshCounts()
    }

    @objc private func refreshTargets() {
        do {
            targets = try inspector.list()
            targetMenu.removeAllItems()
            for item in targets { targetMenu.addItem(withTitle: item.display) }
            targetChanged()
            if targets.isEmpty { showError("夸克没有可读取的窗口/标签页。") }
        } catch { targets = []; targetMenu.removeAllItems(); showError("\(error)") }
    }
    @objc private func targetChanged() {
        guard targets.indices.contains(targetMenu.indexOfSelectedItem) else { targetDetail.stringValue = "尚未选择目标"; return }
        let target = targets[targetMenu.indexOfSelectedItem]
        targetDetail.stringValue = "标题：\(target.title)\nURL：\(target.url)"
    }
    @objc private func importText() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "txt") ?? .plainText]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) else { throw TargetError.message("文件不是有效 UTF-8 文本") }
            textView.string = text
            lastDone = 0; lastTotal = 0
            refreshCounts()
        } catch { showError("读取文本失败：\(error)") }
    }
    @objc private func saveText() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "文本模板.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try textView.string.write(to: url, atomically: true, encoding: .utf8) }
        catch { showError("保存模板失败：\(error)") }
    }
    @objc private func start() {
        guard !engine.isBusy else { showError("已有任务运行中。") ; return }
        guard targets.indices.contains(targetMenu.indexOfSelectedItem) else { showError("请先选择夸克标签页。") ; return }
        let target = targets[targetMenu.indexOfSelectedItem]
        let plan: TypingPlan
        do { plan = try TypingPlan(text: textView.string, milliseconds: settings.milliseconds, variationPercent: settings.variationPercent) }
        catch { showError("\(error)"); return }
        do { try inspector.validateMetadata(target) }
        catch { showError("\(error)"); return }
        if !AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary) {
            showError("需要在系统设置中授予本应用辅助功能权限。"); return
        }
        let alert = NSAlert()
        alert.messageText = "确认本次输入目标"
        alert.informativeText = "标题：\(target.title)\nURL：\(target.url)\n\n确认该页面不是支付页，并将在倒计时内切到夸克、点击目标文本框。"
        alert.addButton(withTitle: "确认并倒计时")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if !engine.start(plan: plan, target: target, countdown: settings.countdown) { showError("已有任务运行中。") }
    }
    @objc private func pause() { engine.pauseOrResume() }
    @objc private func stop() { engine.stop() }
    func pauseForController() { engine.pauseIfTyping() }
    func globalStop() { engine.stop() }
    func showError(_ value: String) { status.stringValue = "错误 · \(value)" }
}
