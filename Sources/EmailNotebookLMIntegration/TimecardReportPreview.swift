import AppKit
import SwiftUI

struct TimecardReportPreview: View {
    let entries: [TimecardEntry]
    let projects: [String]
    let start: Date
    let end: Date
    let onDownload: () -> Void
    let onReturn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Timecards report")
                        .font(.system(size: 23, weight: .semibold, design: .rounded))
                    Text("\(start.formatted(date: .abbreviated, time: .omitted)) - \(end.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Download text file", systemImage: "square.and.arrow.down", action: onDownload)
                Button("Return", systemImage: "arrow.uturn.backward", action: onReturn)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(TimecardReport.weekStartDates(from: start, through: end), id: \.self) { weekStart in
                        TimecardWeekTable(weekStart: weekStart, entries: entries, projects: projects)
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .padding(22)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct TimecardWeekTable: View {
    let weekStart: Date
    let entries: [TimecardEntry]
    let projects: [String]

    private let projectWidth: CGFloat = 150
    private let dayWidth: CGFloat = 88
    private let weeklyWidth: CGFloat = 104
    private let notesWidth: CGFloat = 62

    private var days: [Date] {
        TimecardReport.weekDays(starting: weekStart)
    }

    private var columns: [GridItem] {
        [GridItem(.fixed(projectWidth))]
            + Array(repeating: GridItem(.fixed(dayWidth)), count: 7)
            + [GridItem(.fixed(weeklyWidth)), GridItem(.fixed(notesWidth))]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Week of \(weekStart.formatted(date: .long, time: .omitted))")
                .font(.headline)

            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        headerCell("Project", alignment: .leading)
                        ForEach(days, id: \.self) { day in
                            headerCell(TimecardReport.dayHeading(day), alignment: .center)
                        }
                        headerCell("Weekly Hours", alignment: .center)
                        headerCell("Notes", alignment: .center)
                    }

                    ForEach(projects, id: \.self) { project in
                        GridRow {
                            dataCell(Text(project).fontWeight(.medium), width: projectWidth, alignment: .leading)
                            ForEach(days, id: \.self) { day in
                                dataCell(
                                    Text(TimecardReport.hoursText(TimecardReport.dailyMinutes(entries: entries, project: project, day: day))),
                                    width: dayWidth,
                                    alignment: .center
                                )
                            }
                            dataCell(
                                Text(TimecardReport.hoursText(TimecardReport.weeklyMinutes(entries: entries, project: project, weekStart: weekStart)))
                                    .fontWeight(.semibold),
                                width: weeklyWidth,
                                alignment: .center
                            )
                            dataCell(
                                ProjectNotesButton(project: project, weekStart: weekStart, entries: entries),
                                width: notesWidth,
                                alignment: .center
                            )
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .scrollIndicators(.visible)
        }
    }

    private func headerCell(_ title: String, alignment: Alignment) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(alignment == .leading ? .leading : .center)
            .frame(width: width(for: title), height: 42, alignment: alignment)
            .padding(.horizontal, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: 1)
            }
    }

    private func dataCell<Content: View>(_ content: Content, width: CGFloat, alignment: Alignment) -> some View {
        content
            .frame(width: width, height: 42, alignment: alignment)
            .padding(.horizontal, 6)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.55))
                    .frame(height: 0.5)
            }
    }

    private func width(for title: String) -> CGFloat {
        if title == "Project" { return projectWidth }
        if title == "Weekly Hours" { return weeklyWidth }
        if title == "Notes" { return notesWidth }
        return dayWidth
    }
}

private struct ProjectNotesButton: View {
    let project: String
    let weekStart: Date
    let entries: [TimecardEntry]
    @State private var isShowingNotes = false

    var body: some View {
        Button {
            isShowingNotes = true
        } label: {
            Image(systemName: "note.text")
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help("View daily notes for \(project)")
        .popover(isPresented: $isShowingNotes, arrowEdge: .top) {
            ProjectNotesPopover(project: project, weekStart: weekStart, entries: entries)
        }
    }
}

private struct ProjectNotesPopover: View {
    let project: String
    let weekStart: Date
    let entries: [TimecardEntry]
    @Environment(\.dismiss) private var dismiss

    private var dayNotes: [TimecardDayNotes] {
        TimecardReport.dailyNotes(entries: entries, project: project, weekStart: weekStart)
    }

    private var allNotes: String {
        dayNotes.map { "\(TimecardReport.dayHeading($0.date))\n\($0.text)" }
            .joined(separator: "\n\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(project)
                        .font(.headline)
                    Text("Daily notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Copy all", systemImage: "doc.on.doc") {
                    copyToClipboard(allNotes)
                }
                Button("Return") {
                    dismiss()
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(dayNotes) { notes in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(TimecardReport.dayHeading(notes.date))
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Button {
                                    copyToClipboard(notes.text)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.borderless)
                                .help("Copy this day's notes")
                            }
                            Text(notes.text)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
                                .padding(9)
                                .background(Color.white)
                                .foregroundStyle(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.gray.opacity(0.45), lineWidth: 1)
                                }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 520, height: 540)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}