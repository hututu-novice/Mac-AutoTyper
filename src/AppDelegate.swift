import AppKit
import Carbon

private func hotKeyCallback(_ next: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData = userData else { return noErr }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async { delegate.controller?.globalStop() }
    return noErr
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: ContentViewController?
    private var window: NSWindow?
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "").count > 1 {
            NSApp.terminate(nil)
            return
        }
        let controller = ContentViewController()
        self.controller = controller
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 900), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Mac AutoTyper 1.0"
        window.contentViewController = controller
        window.minSize = NSSize(width: 650, height: 820)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        setupMenu()
        configureHotkey(SavedSettings.load().hotkey)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        for (title, action, key) in [("撤销", "undo:", "z"), ("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        editItem.submenu = editMenu
        menu.addItem(editItem)
        NSApp.mainMenu = menu
    }

    func configureHotkey(_ choice: Int) {
        if let hotKey = hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil }
        if let handler = handler { RemoveEventHandler(handler); self.handler = nil }
        guard choice != 2 else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyCallback, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        let modifiers: UInt32 = choice == 0 ? UInt32(controlKey | optionKey) : UInt32(controlKey | shiftKey)
        let keyID = EventHotKeyID(signature: 0x4D415454, id: 1)
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_S), modifiers, keyID, GetApplicationEventTarget(), 0, &hotKey)
        if status != noErr { controller?.showError("全局停止热键注册失败（\(status)）；仍可使用窗口内停止按钮。") }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        controller?.pauseForController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.globalStop()
        if let hotKey = hotKey { UnregisterEventHotKey(hotKey) }
        if let handler = handler { RemoveEventHandler(handler) }
    }
}
