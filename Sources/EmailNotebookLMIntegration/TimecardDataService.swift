import EventKit
import Foundation
import Combine
import AppKit

@MainActor
final class TimecardDataService: ObservableObject {
    @Published private(set) var calendarEntries: [TimecardEntry] = []
    @Published private(set) var emailEntries: [TimecardEntry] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let eventStore = EKEventStore()

    func load(start: Date, end: Date) async {
        isLoading = true
        errorMessage = nil
        do {
            try await requestCalendarAccess()
            let endExclusive = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: end)) ?? end
            let predicate = eventStore.predicateForEvents(withStart: start, end: endExclusive, calendars: nil)
            calendarEntries = eventStore.events(matching: predicate).map { event in
                TimecardEntry(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    kind: .calendar,
                    title: event.title ?? "Untitled event",
                    date: event.startDate,
                    minutes: max(0, Int((event.endDate.timeIntervalSince(event.startDate) / 60).rounded())),
                    project: nil
                )
            }
            emailEntries = try await Task.detached(priority: .userInitiated) {
                try SentMailFetcher.fetch(start: start, endExclusive: endExclusive)
            }.value
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func requestCalendarAccess() async throws {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            return
        case .notDetermined:
            guard try await eventStore.requestFullAccessToEvents() else {
                throw TimecardDataError.calendarAccessDenied
            }
        default:
            throw TimecardDataError.calendarAccessDenied
        }
    }
}

private enum SentMailFetcher {
    static func fetch(start: Date, endExclusive: Date) throws -> [TimecardEntry] {
        let startOffset = Int(start.timeIntervalSinceNow)
        let endOffset = Int(endExclusive.timeIntervalSinceNow)
        let scriptSource = """
        on run
            set anchorDate to current date
            set rangeStart to anchorDate + (\(startOffset))
            set rangeEnd to anchorDate + (\(endOffset))
            set outputRows to {}
            tell application "Mail"
                repeat with anAccount in every account
                    repeat with aMailbox in every mailbox of anAccount
                        try
                            if (mailbox type of aMailbox) is sent then
                                set matchingMessages to every message of aMailbox whose date sent is greater than or equal to rangeStart and date sent is less than rangeEnd
                                repeat with aMessage in matchingMessages
                                    set sentAt to date sent of aMessage
                                    set sentYear to year of sentAt as integer
                                    set sentMonth to my twoDigits(month of sentAt as integer)
                                    set sentDay to my twoDigits(day of sentAt as integer)
                                    set sentHour to my twoDigits(hours of sentAt as integer)
                                    set sentMinute to my twoDigits(minutes of sentAt as integer)
                                    set sentSecond to my twoDigits(seconds of sentAt as integer)
                                    set sentTimestamp to (sentYear as text) & "-" & sentMonth & "-" & sentDay & "T" & sentHour & ":" & sentMinute & ":" & sentSecond
                                    set messageId to my cleanField((message id of aMessage) as text)
                                    set messageSubject to my cleanField((subject of aMessage) as text)
                                    set end of outputRows to messageId & tab & sentTimestamp & tab & messageSubject
                                end repeat
                            end if
                        end try
                    end repeat
                end repeat
            end tell
            set AppleScript's text item delimiters to return
            return outputRows as text
        end run

        on twoDigits(numberValue)
            if numberValue < 10 then return "0" & (numberValue as text)
            return numberValue as text
        end twoDigits

        on cleanField(theText)
            set oldDelimiters to AppleScript's text item delimiters
            set AppleScript's text item delimiters to {tab, return, linefeed}
            set textParts to text items of theText
            set AppleScript's text item delimiters to " "
            set cleanText to textParts as text
            set AppleScript's text item delimiters to oldDelimiters
            return cleanText
        end cleanField
        """

        guard let script = NSAppleScript(source: scriptSource) else {
            throw TimecardDataError.scriptCreation
        }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            throw TimecardDataError.mail(errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown Apple Mail error")
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return (result.stringValue ?? "").components(separatedBy: "\n").compactMap { row in
            let fields = row.components(separatedBy: "\t")
            guard fields.count >= 3, let sentAt = dateFormatter.date(from: fields[1]) else { return nil }
            return TimecardEntry(
                id: "email-\(fields[0])",
                kind: .email,
                title: fields.dropFirst(2).joined(separator: " "),
                date: sentAt,
                minutes: 15,
                project: nil
            )
        }
    }
}

enum TimecardDataError: LocalizedError {
    case calendarAccessDenied
    case scriptCreation
    case mail(String)

    var errorDescription: String? {
        switch self {
        case .calendarAccessDenied:
            "Calendar access is needed to build a timecard report. Allow it in System Settings > Privacy & Security > Calendars."
        case .scriptCreation:
            "Could not prepare the Apple Mail Sent mailbox query."
        case .mail(let message):
            message
        }
    }
}