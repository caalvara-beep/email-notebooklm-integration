import AppKit
import SwiftUI

struct TimecardsView: View {
    @StateObject private var dataService = TimecardDataService()
    @State private var projects: [String]
    @State private var periodStart = TimecardsView.currentWeekStart
    @State private var periodEnd = Calendar.current.date(byAdding: .day, value: 6, to: TimecardsView.currentWeekStart) ?? Date()
    @State private var calendarEntries: [TimecardEntry] = []
    @State private var emailEntries: [TimecardEntry] = []
    @State private var hasLoaded = false
    @State private var isManagingProjects = false
    @State private var draftProject = ""
    @State private var reportText = ""
    @State private var showingReport = false
    @State private var statusMessage = "Choose a period, then load its activity."

    init() {
        let mappingNames = ConfigurationStore.load().mappings.map(\.label)
        _projects = State(initialValue: TimecardProjectStore.load(mappingNames: mappingNames))
    }

    private static var currentWeekStart: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        return calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Timecards Report")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                    Text("Review sent email and calendar activity by project.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Manage projects", systemImage: "folder.badge.gearshape") {
                    isManagingProjects.toggle()
                }
            }

            HStack(alignment: .bottom, spacing: 12) {
                DatePicker("From", selection: $periodStart, displayedComponents: .date)
                    .frame(maxWidth: 190)
                DatePicker("Through", selection: $periodEnd, displayedComponents: .date)
                    .frame(maxWidth: 190)
                Button("Load activity", systemImage: "arrow.clockwise", action: loadActivity)
                    .buttonStyle(.borderedProminent)
                    .disabled(periodStart > periodEnd || dataService.isLoading)
                if dataService.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if isManagingProjects {
                projectEditor
            }

            if let errorMessage = dataService.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)

            TabView {
                calendarTab
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                emailTab
                    .tabItem { Label("Sent Emails", systemImage: "paperplane") }
            }

            if hasLoaded {
                HStack {
                    Text(reportReadinessMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Create report", systemImage: "doc.text") {
                        reportText = TimecardReport.make(
                            entries: calendarEntries + emailEntries,
                            projects: projects,
                            start: periodStart,
                            end: periodEnd
                        )
                        showingReport = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canGenerateReport)
                }
            }
        }
        .padding(22)
        .frame(minWidth: 820, minHeight: 700)
        .sheet(isPresented: $showingReport) {
            reportPreview
                .frame(minWidth: 680, minHeight: 500)
        }
        .onChange(of: projects) { _, newProjects in
            try? TimecardProjectStore.save(newProjects)
        }
    }

    private var calendarTab: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if calendarEntries.isEmpty && hasLoaded {
                    ContentUnavailableView("No calendar events", systemImage: "calendar", description: Text("No events were found in this period."))
                }
                ForEach($calendarEntries) { $entry in
                    calendarRow(entry: $entry)
                }
            }
            .padding(.vertical, 10)
        }
    }

    private var emailTab: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if emailEntries.isEmpty && hasLoaded {
                    ContentUnavailableView("No sent emails", systemImage: "paperplane", description: Text("No sent messages were found in this period."))
                }
                ForEach($emailEntries) { $entry in
                    emailRow(entry: $entry)
                }
            }
            .padding(.vertical, 10)
        }
    }

    private func calendarRow(entry: Binding<TimecardEntry>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.wrappedValue.title)
                        .font(.headline)
                    Text(entry.wrappedValue.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Exclude", isOn: entry.excluded)
                    .toggleStyle(.checkbox)
            }
            HStack {
                Label("Event duration: \(entry.wrappedValue.minutes) min", systemImage: "clock")
                    .font(.callout)
                Spacer()
                projectPicker(selection: entry.project)
            }
            HStack(spacing: 12) {
                Toggle("Add prep time", isOn: entry.includesPrepTime)
                    .toggleStyle(.checkbox)
                if entry.wrappedValue.includesPrepTime {
                    Picker("Prep", selection: entry.prepMinutes) {
                        ForEach(Array(stride(from: 15, through: 60, by: 15)), id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .frame(width: 150)
                    Text("Added to event duration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func emailRow(entry: Binding<TimecardEntry>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.wrappedValue.title.isEmpty ? "(No subject)" : entry.wrappedValue.title)
                        .font(.headline)
                    Text(entry.wrappedValue.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Exclude", isOn: entry.excluded)
                    .toggleStyle(.checkbox)
            }
            HStack {
                projectPicker(selection: entry.project)
                Spacer()
                Picker("Assigned time", selection: entry.minutes) {
                    ForEach(Array(stride(from: 15, through: 120, by: 15)), id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .frame(width: 160)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func projectPicker(selection: Binding<String?>) -> some View {
        Menu {
            Button("Unassigned") {
                selection.wrappedValue = nil
            }
            Divider()
            ForEach(projects, id: \.self) { project in
                Button {
                    selection.wrappedValue = project
                } label: {
                    if selection.wrappedValue == project {
                        Label(project, systemImage: "checkmark")
                    } else {
                        Text(project)
                    }
                }
            }
        } label: {
            Label(selection.wrappedValue ?? "Choose project", systemImage: "chevron.down")
                .frame(minWidth: 170, alignment: .leading)
        }
        .buttonStyle(.bordered)
    }

    private var projectEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Projects")
                .font(.headline)
            ForEach(projects.indices, id: \.self) { index in
                HStack {
                    TextField("Project name", text: projectBinding(at: index))
                        .textFieldStyle(.roundedBorder)
                    if !["Internal", "Time-off"].contains(projects[index]) {
                        Button(role: .destructive) {
                            projects.remove(at: index)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            HStack {
                TextField("New project name", text: $draftProject)
                    .textFieldStyle(.roundedBorder)
                Button("Add", systemImage: "plus", action: addProject)
                    .disabled(draftProject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private var reportPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Report preview")
                    .font(.headline)
                Spacer()
                Button("Download text file", systemImage: "square.and.arrow.down", action: saveReport)
                Button("Done") {
                    showingReport = false
                }
            }
            TextEditor(text: $reportText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 220)
                .border(Color.gray.opacity(0.4))
        }
    }

    private var canGenerateReport: Bool {
        guard hasLoaded else { return false }
        let includedEntries = (calendarEntries + emailEntries).filter { !$0.excluded }
        return !includedEntries.isEmpty && includedEntries.allSatisfy { $0.project != nil }
    }

    private var reportReadinessMessage: String {
        let includedEntries = (calendarEntries + emailEntries).filter { !$0.excluded }
        let unassignedCount = includedEntries.filter { $0.project == nil }.count
        if includedEntries.isEmpty {
            return "No included activity to report."
        }
        if unassignedCount > 0 {
            return "Assign a project or exclude each of the \(unassignedCount) remaining items."
        }
        return "All included activity is assigned."
    }

    private func projectBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { projects[index] },
            set: { newName in
                let oldName = projects[index]
                projects[index] = newName
                for entryIndex in calendarEntries.indices where calendarEntries[entryIndex].project == oldName {
                    calendarEntries[entryIndex].project = newName
                }
                for entryIndex in emailEntries.indices where emailEntries[entryIndex].project == oldName {
                    emailEntries[entryIndex].project = newName
                }
            }
        )
    }

    private func addProject() {
        let name = draftProject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !projects.contains(name) else { return }
        projects.append(name)
        draftProject = ""
    }

    private func loadActivity() {
        let start = Calendar.current.startOfDay(for: periodStart)
        let end = Calendar.current.startOfDay(for: periodEnd)
        hasLoaded = false
        reportText = ""
        statusMessage = "Loading Calendar events and sent email…"
        Task {
            await dataService.load(start: start, end: end)
            calendarEntries = dataService.calendarEntries
            emailEntries = dataService.emailEntries
            hasLoaded = dataService.errorMessage == nil
            if let errorMessage = dataService.errorMessage {
                statusMessage = errorMessage
            } else {
                statusMessage = "Loaded \(calendarEntries.count) calendar events and \(emailEntries.count) sent emails."
            }
        }
    }

    private func saveReport() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = TimecardReport.filename(start: periodStart, end: periodEnd)
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try reportText.write(to: url, atomically: true, encoding: .utf8)
            statusMessage = "Report saved to \(url.lastPathComponent)"
        } catch {
            statusMessage = "Could not save report: \(error.localizedDescription)"
        }
    }
}

private enum TimecardProjectStore {
    private static let fileURL = ConfigurationStore.directory.appending(path: "timecard-projects.json")

    static func load(mappingNames: [String]) -> [String] {
        let saved = (try? Data(contentsOf: fileURL)).flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        let defaults = ["Internal", "Time-off"]
        let projects = unique(saved + mappingNames + defaults)
        try? save(projects)
        return projects
    }

    static func save(_ projects: [String]) throws {
        try FileManager.default.createDirectory(at: ConfigurationStore.directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(unique(projects))
        try data.write(to: fileURL, options: .atomic)
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}