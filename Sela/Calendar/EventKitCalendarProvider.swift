import Combine
import EventKit
import Foundation

/// Read-only EventKit access. Queries run inside this actor, never on the main actor.
actor EventKitCalendarProvider: CalendarProviding {
    nonisolated let storeChanged: AnyPublisher<Void, Never>

    private let store = EKEventStore()

    init() {
        storeChanged = NotificationCenter.default
            .publisher(for: .EKEventStoreChanged)
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func authorizationStatus() -> CalendarAccess {
        Self.access(from: EKEventStore.authorizationStatus(for: .event))
    }

    func requestAccess() async -> CalendarAccess {
        if #available(macOS 14.0, *) {
            _ = try? await store.requestFullAccessToEvents()
        } else {
            _ = await withCheckedContinuation { continuation in
                store.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
        return authorizationStatus()
    }

    func events(from start: Date, to end: Date) async throws -> [CalendarEvent] {
        guard authorizationStatus() == .authorized else { return [] }

        let calendars = store.calendars(for: .event)
        guard !calendars.isEmpty else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate).compactMap(snapshot)
    }

    private func snapshot(_ event: EKEvent) -> CalendarEvent? {
        guard let start = event.startDate, let end = event.endDate else { return nil }

        let links = CalendarLinkDetector.links(
            eventURL: event.url,
            location: event.location,
            notes: event.notes
        )
        let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines)
        let declined = event.attendees?.contains {
            $0.isCurrentUser && $0.participantStatus == .declined
        } ?? false

        return CalendarEvent(
            id: "\(event.eventIdentifier ?? "event")-\(start.timeIntervalSince1970)",
            title: event.title ?? "",
            start: start,
            end: end,
            isAllDay: event.isAllDay,
            location: location?.isEmpty == false ? location : nil,
            meetingURL: links.meeting,
            eventURL: links.event,
            isCancelled: event.status == .canceled,
            isDeclined: declined
        )
    }

    private static func access(from status: EKAuthorizationStatus) -> CalendarAccess {
        if #available(macOS 14.0, *) {
            switch status {
            case .fullAccess: return .authorized
            case .writeOnly, .denied: return .denied
            case .restricted: return .restricted
            case .notDetermined: return .needsPermission
            @unknown default: return .denied
            }
        } else {
            switch status {
            case .authorized: return .authorized
            case .denied: return .denied
            case .restricted: return .restricted
            case .notDetermined: return .needsPermission
            default: return .denied
            }
        }
    }
}
