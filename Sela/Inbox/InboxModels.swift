import Foundation

enum InboxSource: String, CaseIterable, Identifiable {
    case whatsapp
    case telegram
    case messages
    case simulation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .whatsapp: "WhatsApp"
        case .telegram: "Telegram"
        case .messages: "Messages"
        case .simulation: "Simulasi"
        }
    }

    var symbolName: String {
        switch self {
        case .whatsapp: "message.fill"
        case .telegram: "paperplane.fill"
        case .messages: "bubble.left.and.bubble.right.fill"
        case .simulation: "sparkles"
        }
    }

    var bundleIdentifier: String? {
        switch self {
        case .whatsapp: "net.whatsapp.WhatsApp"
        case .telegram: "ru.keepcoder.Telegram"
        case .messages: "com.apple.MobileSMS"
        case .simulation: nil
        }
    }

    var isExperimentalSource: Bool { self != .simulation }

    static var selectable: [InboxSource] { [.whatsapp, .telegram, .messages] }

    static func match(_ text: String) -> InboxSource? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch value {
        case "whatsapp": return .whatsapp
        case "telegram": return .telegram
        case "messages", "pesan", "imessage": return .messages
        default: return nil
        }
    }
}

struct InboxItem: Identifiable, Equatable {
    let id: UUID
    let source: InboxSource
    let sender: String?
    let title: String?
    let body: String?
    let receivedAt: Date
    var isRead: Bool

    var headline: String { sender ?? title ?? source.displayName }

    var preview: String? {
        if let body, !body.isEmpty { return body }
        if sender != nil, let title, !title.isEmpty { return title }
        return nil
    }
}

struct InboxBannerReading: Equatable {
    let source: InboxSource
    let sender: String?
    let title: String?
    let body: String?

    var fingerprint: String {
        [source.rawValue, sender ?? "", title ?? "", body ?? ""].joined(separator: "\u{1F}")
    }
}

enum InboxLimits {
    static let capacity = 20
    static let duplicateWindow: TimeInterval = 30
    static let maxTextLength = 300
}

enum InboxURL {
    static let scheme = "notchapp"
    static let host = "notify"

    static func reading(from url: URL) -> InboxBannerReading? {
        guard url.scheme?.lowercased() == scheme, url.host?.lowercased() == host else { return nil }

        var query: [String: String] = [:]
        for item in URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [] {
            query[item.name.lowercased()] = item.value ?? ""
        }

        let sender = clean(query["sender"])
        let title = clean(query["title"])
        let body = clean(query["body"])

        guard sender != nil || title != nil || body != nil else {
            return InboxBannerReading(source: .simulation, sender: nil, title: "Notifikasi uji", body: nil)
        }
        return InboxBannerReading(source: .simulation, sender: sender, title: title, body: body)
    }

    static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(InboxLimits.maxTextLength))
    }
}
