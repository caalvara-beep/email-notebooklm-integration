import Foundation

enum TimecardEntryKind: String, Sendable {
    case calendar
    case email
}

struct TimecardEntry: Identifiable, Equatable, Sendable {
    let id: String
    let kind: TimecardEntryKind
    let title: String
    let date: Date
    var minutes: Int
    var project: String?
    var excluded = false
    var includesPrepTime = false
    var prepMinutes = 15

    var reportMinutes: Int {
        minutes + (kind == .calendar && includesPrepTime ? prepMinutes : 0)
    }
}

enum TimecardReport {
    static func make(entries: [TimecardEntry], projects: [String], start: Date, end: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = 1
        calendar.minimumDaysInFirstWeek = 1

        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let eligibleEntries = entries.filter { !$0.excluded && $0.project != nil }
        var weekStarts: [Date] = []
        var weekCursor = calendar.dateInterval(of: .weekOfYear, for: startDay)?.start ?? startDay
        while weekCursor <= endDay {
            weekStarts.append(weekCursor)
            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: weekCursor) else { break }
            weekCursor = nextWeek
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = calendar
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.calendar = calendar
        dayFormatter.dateFormat = "EEEE"

        var sections: [String] = []
        for weekStart in weekStarts {
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { continue }
            let weekAfterEnd = calendar.date(byAdding: .day, value: 1, to: weekEnd) ?? weekEnd
            let weekEntries = eligibleEntries.filter { $0.date >= weekStart && $0.date < weekAfterEnd }
            var lines = [
                "Week Start: \(dateFormatter.string(from: weekStart))",
                "Week End: \(dateFormatter.string(from: weekEnd))",
                "",
                "Project daily hours:"
            ]

            for project in projects {
                lines.append(project + ":")
                var weeklyMinutes = 0
                for dayOffset in 0..<7 {
                    guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
                    let minutes = weekEntries
                        .filter { $0.project == project && calendar.isDate($0.date, inSameDayAs: day) }
                        .reduce(0) { $0 + $1.reportMinutes }
                    weeklyMinutes += minutes
                    lines.append("\(dayFormatter.string(from: day)) Hours: \(hours(minutes))")
                }
                lines.append("Weekly total: \(hours(weeklyMinutes))")
                lines.append("")
            }

            lines.append("Daily notes:")
            for project in projects {
                lines.append(project)
                for dayOffset in 0..<7 {
                    guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
                    lines.append("\(dayFormatter.string(from: day)) notes:")
                    let dayEntries = weekEntries.filter {
                        $0.project == project && calendar.isDate($0.date, inSameDayAs: day)
                    }
                    let calendarEntries = dayEntries.filter { $0.kind == .calendar }
                    for entry in calendarEntries {
                        lines.append("- \(entry.title) (\(entry.reportMinutes) min)")
                    }
                    let emailGroups = Dictionary(grouping: dayEntries.filter { $0.kind == .email }, by: \.title)
                    for subject in emailGroups.keys.sorted() {
                        let minutes = emailGroups[subject, default: []].reduce(0) { $0 + $1.reportMinutes }
                        lines.append("- Email: \(subject) (\(minutes) min)")
                    }
                }
                lines.append("")
            }
            sections.append(lines.joined(separator: "\n"))
        }
        return sections.joined(separator: "\n\n========================================\n\n")
    }

    static func filename(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: start)) to \(formatter.string(from: end))-timecards report.txt"
    }

    private static func hours(_ minutes: Int) -> String {
        let value = Double(minutes) / 60
        return String(format: "%.2f", value).replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }
}