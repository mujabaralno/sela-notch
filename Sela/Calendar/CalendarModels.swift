import Foundation

enum CalendarAccess: Equatable {
    case unknown
    case needsPermission
    case denied
    case restricted
    case authorized
}

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    let meetingURL: URL?
    let eventURL: URL?
    let isCancelled: Bool
    let isDeclined: Bool
}

enum CalendarEventKind: Equatable {
    case ongoing
    case upcoming
    case allDay
}

struct CalendarLinks: Equatable {
    let meeting: URL?
    let event: URL?

    var primary: URL? { meeting ?? event }
}

enum CalendarLinkDetector {
    static func links(eventURL: URL?, location: String?, notes: String?) -> CalendarLinks {
        var candidates: [URL] = []
        if let eventURL, let normalized = normalized(eventURL) {
            candidates.append(normalized)
        }
        candidates.append(contentsOf: urls(in: location))
        candidates.append(contentsOf: urls(in: notes))

        var seen = Set<String>()
        let unique = candidates.filter { seen.insert($0.absoluteString).inserted }
        return CalendarLinks(
            meeting: unique.first(where: isMeeting),
            event: unique.first(where: { !isMeeting($0) })
        )
    }

    static func isMeeting(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }

        if host == "meet.google.com" { return true }
        if host == "zoom.us" || host.hasSuffix(".zoom.us") { return true }
        if host == "zoomgov.com" || host.hasSuffix(".zoomgov.com") { return true }
        if host.hasSuffix("teams.microsoft.com") || host.hasSuffix("teams.microsoft.us") { return true }
        if host == "teams.live.com" { return true }
        if host == "webex.com" || host.hasSuffix(".webex.com") { return true }
        if host == "whereby.com" || host.hasSuffix(".whereby.com") { return true }
        if host == "meet.jit.si" || host.contains("jitsi") { return true }
        return false
    }

    private static func urls(in text: String?) -> [URL] {
        guard let text, !text.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return [] }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.matches(in: text, range: range).compactMap { match in
            match.url.flatMap(normalized)
        }
    }

    private static func normalized(_ url: URL) -> URL? {
        if let scheme = url.scheme?.lowercased() {
            guard scheme == "http" || scheme == "https" else { return nil }
            return url
        }
        return URL(string: "https://" + url.absoluteString)
    }
}

enum CalendarAgenda {
    static let horizonDays = 7
    static let lookbackDays = 7

    static func end(from now: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: horizonDays, to: now)
            ?? now.addingTimeInterval(TimeInterval(horizonDays * 86_400))
    }

    static func fetchStart(from now: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -lookbackDays, to: now)
            ?? now.addingTimeInterval(TimeInterval(-lookbackDays * 86_400))
    }

    static func visibleEvents(from events: [CalendarEvent], now: Date, calendar: Calendar = .current) -> [CalendarEvent] {
        let limit = end(from: now, calendar: calendar)
        return events
            .filter { !$0.isCancelled && !$0.isDeclined && $0.end > now && $0.start < limit }
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay { return !lhs.isAllDay }
                if lhs.start != rhs.start { return lhs.start < rhs.start }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    static func kind(of event: CalendarEvent, now: Date) -> CalendarEventKind {
        if event.isAllDay { return .allDay }
        return event.start <= now && event.end > now ? .ongoing : .upcoming
    }
}
