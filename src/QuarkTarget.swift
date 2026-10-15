import AppKit
import ApplicationServices

struct QuarkTarget: Equatable {
    let windowID: String
    let tabID: String
    let title: String
    let url: String

    var display: String { "\(title)  ·  \(url)  [窗口 \(windowID)，标签 \(tabID)]" }
}

enum TargetError: Error, CustomStringConvertible {
    case message(String)
    var description: String { if case .message(let value) = self { return value }; return "目标不可用" }
}

final class QuarkInspector {
    private var lockedFocus: AXUIElement?
    private var lockedWebArea: AXUIElement?
    private var lockedWindow: AXUIElement?
    func resetFocus() { lockedFocus = nil; lockedWebArea = nil; lockedWindow = nil }

    static let bundleID = "com.quark.desktop"

    private func runScript(_ body: String) throws -> String {
        guard let script = NSAppleScript(source: "tell application id \"com.quark.desktop\"\n\(body)\nend tell") else {
            throw TargetError.message("无法创建夸克自动化查询。")
        }
        var error: NSDictionary?
        let value = script.executeAndReturnError(&error)
        if let error = error {
            throw TargetError.message("无法读取夸克窗口/标签页；请允许自动化访问。\n\(error)")
        }
        return value.stringValue ?? ""
    }

    func list() throws -> [QuarkTarget] {
        let body = """
        set rows to {}
        repeat with w in windows
            repeat with t in tabs of w
                set end of rows to ((id of w as text) & (ASCII character 31) & (id of t as text) & (ASCII character 31) & (title of t as text) & (ASCII character 31) & (URL of t as text))
            end repeat
        end repeat
        set AppleScript's text item delimiters to ASCII character 30
        return rows as text
        """
        let result = try runScript(body)
        return result.split(separator: "\u{1E}", omittingEmptySubsequences: true).compactMap { row in
            let values = row.split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
            guard values.count == 4 else { return nil }
            return QuarkTarget(windowID: values[0], tabID: values[1], title: values[2], url: values[3])
        }
    }

    func active() throws -> QuarkTarget {
        let result = try runScript("""
        set w to front window
        set t to active tab of w
        return (id of w as text) & (ASCII character 31) & (id of t as text) & (ASCII character 31) & (title of t as text) & (ASCII character 31) & (URL of t as text)
        """)
        let values = result.split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
        guard values.count == 4 else { throw TargetError.message("无法核验夸克当前标签页。") }
        return QuarkTarget(windowID: values[0], tabID: values[1], title: values[2], url: values[3])
    }

    func validate(_ target: QuarkTarget, multiline: Bool) throws {
        try validateMetadata(target)
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              frontmost.bundleIdentifier == Self.bundleID else {
            throw TargetError.message("夸克不是当前前台应用，已停止。")
        }
        if lockedWebArea == nil {
            guard try active() == target else {
                throw TargetError.message("窗口、标签页、标题或 URL 已变化，已停止。")
            }
        }
        let app = AXUIElementCreateApplication(frontmost.processIdentifier)
        var enhanced: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, "AXEnhancedUserInterface" as CFString, &enhanced) == .success,
           let enabled = enhanced as? Bool, !enabled {
            let result = AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
            guard result == .success else {
                throw TargetError.message("夸克未开放增强辅助功能，无法核验网页输入焦点。")
            }
        }
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else { throw TargetError.message("无法核验输入焦点；请授予辅助功能权限并点击网页文本框。") }
        let ax = element as! AXUIElement
        func string(_ attribute: String) -> String? {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(ax, attribute as CFString, &value) == .success else { return nil }
            return value as? String
        }
        let role = string(kAXRoleAttribute) ?? ""
        let subrole = string(kAXSubroleAttribute) ?? ""
        if role == "AXSecureTextField" || subrole == "AXSecureTextField" {
            throw TargetError.message("密码输入框被禁止。")
        }
        guard ["AXTextArea", "AXTextField", "AXComboBox"].contains(role) else {
            throw TargetError.message("焦点不是可核验的文本编辑元素（\(role)）。")
        }
        if multiline && role != "AXTextArea" {
            throw TargetError.message("多行原文只能输入到可核验的多行文本框。")
        }
        var ancestor = ax
        var webArea: AXUIElement?
        var window: AXUIElement?
        for _ in 0..<40 {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(ancestor, kAXRoleAttribute as CFString, &value) == .success {
                if value as? String == "AXWebArea" { webArea = ancestor }
                if value as? String == "AXWindow" { window = ancestor; break }
            }
            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(ancestor, kAXParentAttribute as CFString, &parent) == .success,
                  let parent = parent, CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
            ancestor = (parent as! AXUIElement)
        }
        guard let webArea = webArea, let window = window else {
            throw TargetError.message("焦点不在可核验的夸克网页窗口中，已停止。")
        }
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let focusedWindow = focusedWindow, CFEqual(focusedWindow, window) else {
            throw TargetError.message("夸克窗口焦点已变化，已停止。")
        }
        func attribute(_ element: AXUIElement, _ name: String) -> String? {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
            return value as? String
        }
        guard attribute(webArea, kAXTitleAttribute) == target.title,
              attribute(window, "AXDocument") == target.url else {
            throw TargetError.message("网页标题或 URL 已变化，已停止。")
        }
        if let original = lockedWebArea, !CFEqual(original, webArea) {
            throw TargetError.message("夸克标签页已变化，已停止。")
        }
        if let original = lockedWindow, !CFEqual(original, window) {
            throw TargetError.message("夸克窗口已变化，已停止。")
        }
        if let original = lockedFocus, !CFEqual(original, ax) {
            throw TargetError.message("网页输入框已变化，已停止。")
        }
        var settable = DarwinBoolean(false)
        let status = AXUIElementIsAttributeSettable(ax, kAXValueAttribute as CFString, &settable)
        guard status == .success && settable.boolValue else {
            throw TargetError.message("焦点文本框不可编辑或无法核验。")
        }
        lockedFocus = ax
        lockedWebArea = webArea
        lockedWindow = window
    }

    func validateMetadata(_ target: QuarkTarget) throws {
        guard let url = URL(string: target.url), let scheme = url.scheme?.lowercased(), ["file", "http", "https"].contains(scheme) else {
            throw TargetError.message("仅允许可核验的本地或网页标签页。")
        }
        let marker = (target.url + " " + target.title).lowercased()
        let blocked = ["checkout", "payment", "billing", "pay.", "/pay", "支付", "付款", "收银", "账单", "银行卡", "信用卡"]
        if blocked.contains(where: marker.contains) { throw TargetError.message("疑似支付页面，已拒绝输入。") }
    }
}
