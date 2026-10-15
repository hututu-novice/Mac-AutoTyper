import Foundation

enum TypingIssue: Error, Equatable, CustomStringConvertible {
    case empty
    case unsupportedControl(String)
    case invalidSpeed

    var description: String {
        switch self {
        case .empty: return "请输入要模拟输入的文本。"
        case .unsupportedControl(let value): return "原文含无法保持原样的控制字符：\(value)。"
        case .invalidSpeed: return "速度必须在每字符 20–2000 毫秒之间。"
        }
    }
}

struct TypingPlan {
    let text: String
    let characters: [Character]
    let milliseconds: Int
    let variationPercent: Int

    init(text: String, milliseconds: Int, variationPercent: Int) throws {
        guard !text.isEmpty else { throw TypingIssue.empty }
        guard (20...2000).contains(milliseconds), (0...20).contains(variationPercent) else {
            throw TypingIssue.invalidSpeed
        }
        for scalar in text.unicodeScalars {
            if scalar.value < 32 && scalar.value != 10 {
                throw TypingIssue.unsupportedControl(String(format: "U+%04X", scalar.value))
            }
            if scalar.value == 127 || (0x80...0x9F).contains(scalar.value) || scalar.value == 0x2028 || scalar.value == 0x2029 {
                throw TypingIssue.unsupportedControl(String(format: "U+%04X", scalar.value))
            }
        }
        for character in text where String(character).utf16.count > 20 {
            throw TypingIssue.unsupportedControl("超长 Unicode 字符簇")
        }
        self.text = text
        self.characters = Array(text)
        self.milliseconds = milliseconds
        self.variationPercent = variationPercent
    }

    var estimatedSeconds: Double { Double(characters.count * milliseconds) / 1000 }
    var words: Int { text.split(whereSeparator: { $0.isWhitespace }).count }
    var wpm: Int { Int((60_000.0 / Double(milliseconds) / 5.0).rounded()) }

    func delay() -> TimeInterval {
        let jitter = Double.random(in: -Double(variationPercent)...Double(variationPercent)) / 100
        return Double(milliseconds) * (1 + jitter) / 1000
    }
}

struct SavedSettings: Codable {
    var milliseconds = 100
    var variationPercent = 0
    var countdown = 5
    var hotkey = 0

    static var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Mac-AutoTyper/settings.json")
    }
    static func load() -> SavedSettings {
        guard let data = try? Data(contentsOf: url), let settings = try? JSONDecoder().decode(Self.self, from: data) else {
            return SavedSettings()
        }
        return settings
    }
    func save() throws {
        try FileManager.default.createDirectory(at: Self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: Self.url, options: .atomic)
    }
}
