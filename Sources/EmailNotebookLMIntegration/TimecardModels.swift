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
    var assignmentKey: String? = nil
    var minutes: Int
    var project: String?
    var excluded = false
    var includesPrepTime = false
    var prepMinutes = 15

    var reportMinutes: Int {
        minutes + (kind == .calendar && includesPrepTime ? prepMinutes : 0)
    }
}

struct TimecardDayNotes: Identifiable, Sendable {
    let date: Date
    let text: String

    var id: Date { date }
}

enum TimecardReport {
    static func weekStartDates(from start: Date, through end: Date) -> [Date] {
        let calendar = reportCalendar()
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard startDay <= endDay else { return [] }

        var weeks: [Date] = []
        var cursor = calendar.dateInterval(of: .weekOfYear, for: startDay)?.start ?? startDay
        while cursor <= endDay {
            weeks.append(cursor)
            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: cursor) else { break }
            cursor = nextWeek
        }
        return weeks
    }

    static func weekDays(starting weekStart: Date) -> [Date] {
        let calendar = reportCalendar()
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    static func dayHeading(_ date: Date) -> String {
        let weekday = date.formatted(.dateTime.weekday(.wide))
        let dayAndMonth = date.formatted(.dateTime.day().month(.twoDigits))
        return "\(weekday) \(dayAndMonth)"
    }

    static func dailyMinutes(entries: [TimecardEntry], project: String, day: Date) -> Int {
        let calendar = reportCalendar()
        return entries
            .filter { !$0.excluded && $0.project == project && calendar.isDate($0.date, inSameDayAs: day) }
            .reduce(0) { $0 + $1.reportMinutes }
    }

    static func weeklyMinutes(entries: [TimecardEntry], project: String, weekStart: Date) -> Int {
        weekDays(starting: weekStart).reduce(0) {
            $0 + dailyMinutes(entries: entries, project: project, day: $1)
        }
    }

    static func dailyNotes(entries: [TimecardEntry], project: String, weekStart: Date) -> [TimecardDayNotes] {
        let calendar = reportCalendar()
        return weekDays(starting: weekStart).map { day in
            let matching = entries.filter {
                !$0.excluded && $0.project == project && calendar.isDate($0.date, inSameDayAs: day)
            }
            let eventNotes = matching.filter { $0.kind == .calendar }.map {
                "- \($0.title) (\($0.reportMinutes) min)"
            }
            let emailGroups = Dictionary(grouping: matching.filter { $0.kind == .email }, by: \.title)
            let emailNotes = emailGroups.keys.sorted().map { subject in
                let minutes = emailGroups[subject, default: []].reduce(0) { $0 + $1.reportMinutes }
                let displaySubject = subject.isEmpty ? "(No subject)" : subject
                return "- Email: \(displaySubject) (\(minutes) min)"
            }
            let notes = eventNotes + emailNotes
            return TimecardDayNotes(date: day, text: notes.isEmpty ? "No notes for this day." : notes.joined(separator: "\n"))
        }
    }

    static func make(entries: [TimecardEntry], projects: [String], start: Date, end: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = 1
        calendar.minimumDaysInFirstWeek = 1

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = calendar
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.calendar = calendar
        dayFormatter.dateFormat = "EEEE"

        var sections: [String] = []
        for weekStart in weekStartDates(from: start, through: end) {
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { continue }
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
                    let minutes = dailyMinutes(entries: entries, project: project, day: day)
                    weeklyMinutes += minutes
                    lines.append("\(dayFormatter.string(from: day)) Hours: \(hoursText(minutes))")
                }
                lines.append("Weekly total: \(hoursText(weeklyMinutes))")
                lines.append("")
            }

            lines.append("Daily notes:")
            for project in projects {
                lines.append(project)
                for dayNotes in dailyNotes(entries: entries, project: project, weekStart: weekStart) {
                    lines.append("\(dayFormatter.string(from: dayNotes.date)) notes:")
                    if dayNotes.text != "No notes for this day." {
                        lines.append(contentsOf: dayNotes.text.components(separatedBy: "\n"))
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

    static func hoursText(_ minutes: Int) -> String {
        let value = Double(minutes) / 60
        return String(format: "%.2f", value).replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }

    private static func reportCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = 1
        calendar.minimumDaysInFirstWeek = 1
        return calendar
    }
}