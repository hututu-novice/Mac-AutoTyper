import AppKit
import ApplicationServices

enum RunState: String { case idle = "就绪", countdown = "倒计时", typing = "输入中", paused = "已暂停", stopped = "已停止", finished = "已完成", failed = "错误" }

// All state, validation and posting are serialized on the main queue. A cancelled
// timer cannot emit characters into a later task because it carries a generation.
final class TypingEngine {
    var onUpdate: ((RunState, Int, Int, TimeInterval, String) -> Void)?
    private var state: RunState = .idle
    private var generation = 0
    private let inspector = QuarkInspector()
    private var plan: TypingPlan?
    private var target: QuarkTarget?
    private var done = 0
    private var started = Date()
    private var source: CGEventSource?
    private var activity: NSObjectProtocol?
    var isBusy: Bool { [.countdown, .typing, .paused].contains(state) }

    private func update(_ next: RunState, _ message: String) {
        state = next
        maintainActivity(next == .countdown || next == .typing)
        onUpdate?(next, done, plan?.characters.count ?? 0, Date().timeIntervalSince(started), message)
    }

    private func maintainActivity(_ active: Bool) {
        if active && activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep,
                                                              reason: "Typing user-requested text into Quark")
        } else if !active, let current = activity {
            ProcessInfo.processInfo.endActivity(current)
            activity = nil
        }
    }

    func start(plan: TypingPlan, target: QuarkTarget, countdown: Int) -> Bool {
        precondition(Thread.isMainThread)
        guard !isBusy else { return false }
        generation += 1
        self.plan = plan; self.target = target; done = 0; started = Date()
        inspector.resetFocus()
        source = CGEventSource(stateID: .hidSystemState)
        guard source != nil else { update(.failed, "无法创建键盘事件源"); return false }
        maintainActivity(true)
        countDown(max(0, countdown), id: generation)
        return true
    }

    private func countDown(_ remaining: Int, id: Int) {
        guard id == generation else { return }
        if remaining == 0 { state = .typing; tick(id); return }
        update(.countdown, "\(remaining) 秒后开始；请切回原文本框；可取消")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.countDown(remaining - 1, id: id)
        }
    }

    private func tick(_ id: Int) {
        guard id == generation, state == .typing, let plan = plan, let target = target else { return }
        // Returning to the controller must pause before the user can click its UI.
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
            pauseIfTyping()
            return
        }
        do { try inspector.validate(target, multiline: plan.text.contains("\n")) }
        catch { update(.failed, "\(error)"); return }
        guard id == generation, state == .typing else { return }
        let character = plan.characters[done]
        let units = Array(String(character).utf16)
        let key: CGKeyCode = character == "\n" ? 36 : 0
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else {
            update(.failed, "该字符无法生成键盘事件"); return
        }
        if character != "\n" {
            down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        done += 1
        if done == plan.characters.count {
            update(.finished, "输入任务结束；请比较网页实际内容与原文")
        } else {
            update(.typing, "正在输入")
            DispatchQueue.main.asyncAfter(deadline: .now() + plan.delay()) { [weak self] in self?.tick(id) }
        }
    }

    func pauseIfTyping() {
        guard state == .typing else { return }
        generation += 1
        update(.paused, "已暂停；继续后有 3 秒切回原文本框")
    }

    func pauseOrResume() {
        precondition(Thread.isMainThread)
        if state == .typing { pauseIfTyping() }
        else if state == .paused {
            generation += 1
            countDown(3, id: generation)
        }
    }

    func stop() {
        precondition(Thread.isMainThread)
        guard isBusy else { return }
        generation += 1
        update(.stopped, "已取消或停止")
    }
}
