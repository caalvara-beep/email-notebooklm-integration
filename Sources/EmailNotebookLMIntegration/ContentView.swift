import AppKit
import SwiftUI

struct EmailSyncView: View {
    @State private var configuration = ConfigurationStore.load()
    @State private var statusMessage = "Ready"
    @State private var isRunning = false
    @State private var draftLabel = ""
    @State private var draftAccount = ""
    @State private var draftMailbox = ""
    @State private var draftDestination = ""
    @State private var editingMappingIDs: Set<UUID> = []
    @State private var isAddingMapping = false
    @State private var scheduleIsLoaded = false
    @State private var lastSyncDates: [UUID: Date] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Form {
                Section("Mailbox destinations") {
                    if configuration.mappings.isEmpty {
                        Text("Add a mailbox to begin.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach($configuration.mappings) { $mapping in
                        mappingRow(mapping: $mapping)
                    }

                    if isAddingMapping {
                        addMappingFields
                    }

                    Button("Add mailbox", systemImage: "plus") {
                        isAddingMapping = true
                    }
                    .disabled(isAddingMapping)
                }

                Section("Automatic export") {
                    Toggle("Run automatically", isOn: $configuration.scheduleEnabled)
                    Picker("Frequency", selection: $configuration.frequency) {
                        ForEach(ExportFrequency.allCases) { frequency in
                            Text(frequency.title).tag(frequency)
                        }
                    }
                    .disabled(!configuration.scheduleEnabled)
                    HStack {
                        Image(systemName: scheduleStatusIcon)
                            .foregroundStyle(scheduleIsLoaded ? .green : .secondary)
                        Text(scheduleStatusText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Check status", systemImage: "arrow.clockwise") {
                            refreshStatus()
                        }
                    }
                }
            }
            .formStyle(.grouped)

            footer
        }
        .frame(minWidth: 680, minHeight: 620)
        .onChange(of: configuration) { _, newValue in
            saveConfiguration(newValue)
        }
        .onChange(of: configuration.scheduleEnabled) { _, _ in
            updateSchedule()
        }
        .onChange(of: configuration.frequency) { _, _ in
            updateSchedule()
        }
        .onAppear {
            refreshStatus()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Email to NotebookLM")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                Text("Apple Mail  ·  Monthly transcript files  ·  Google Drive")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                runExport()
            } label: {
                Label(isRunning ? "Exporting…" : "Run now", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning || configuration.mappings.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func mappingFields(mapping: Binding<MailboxMapping>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            inputField("Mapping name", text: mapping.label)
                .font(.headline)
            HStack {
                inputField("Mail account name or email", text: mapping.accountName)
                inputField("Mailbox name", text: mapping.mailboxName)
            }
            HStack {
                inputField("Google Drive destination folder", text: mapping.destinationPath)
                Button {
                    chooseFolder(for: mapping)
                } label: {
                    Image(systemName: "folder")
                }
                .help("Choose destination folder")
            }
        }
        .padding(.vertical, 6)
    }

    private func mappingRow(mapping: Binding<MailboxMapping>) -> some View {
        let mappingID = mapping.wrappedValue.id
        let isEditing = editingMappingIDs.contains(mappingID)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(mapping.wrappedValue.label)
                        .font(.headline)
                    Text("\(mapping.wrappedValue.accountName) · \(mapping.wrappedValue.mailboxName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(lastSyncDescription(for: mapping.wrappedValue.id))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(isEditing ? "Done" : "Edit", systemImage: isEditing ? "checkmark" : "pencil") {
                    if isEditing {
                        editingMappingIDs.remove(mappingID)
                    } else {
                        editingMappingIDs.insert(mappingID)
                    }
                }
                .buttonStyle(.borderless)
                Button(role: .destructive) {
                    removeMapping(mappingID)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove this mailbox mapping")
            }
            if isEditing {
                mappingFields(mapping: mapping)
            }
        }
        .padding(.vertical, 5)
    }

    private var addMappingFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add mailbox")
                .font(.headline)
            HStack {
                inputField("Mapping name", text: $draftLabel)
                inputField("Mail account name or email", text: $draftAccount)
            }
            HStack {
                inputField("Mailbox name", text: $draftMailbox)
                inputField("Google Drive folder path", text: $draftDestination)
                Button {
                    chooseFolder { draftDestination = $0.path }
                } label: {
                    Image(systemName: "folder")
                }
                .help("Choose destination folder")
                Button("Save", systemImage: "checkmark", action: addMapping)
                    .disabled(draftLabel.isEmpty || draftAccount.isEmpty || draftMailbox.isEmpty || draftDestination.isEmpty)
            }
        }
        .padding(.vertical, 6)
    }

    private func inputField(_ prompt: String, text: Binding<String>) -> some View {
        TextField(prompt, text: text)
            .textFieldStyle(.plain)
            .foregroundStyle(Color.black)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.gray.opacity(0.55), lineWidth: 1)
            }
    }

    private var footer: some View {
        HStack {
            Circle()
                .fill(isRunning ? .orange : .green)
                .frame(width: 8, height: 8)
            Text(statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text("First run imports existing mail; later runs skip exported message IDs.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var scheduleStatusIcon: String {
        if scheduleIsLoaded { return "checkmark.circle.fill" }
        return configuration.scheduleEnabled ? "exclamationmark.circle.fill" : "pause.circle"
    }

    private var scheduleStatusText: String {
        if configuration.scheduleEnabled {
            return scheduleIsLoaded ? "Automatic export is loaded in launchd." : "Enabled in settings, but no launchd job is loaded."
        }
        return scheduleIsLoaded ? "A launchd job is loaded, but automatic export is switched off." : "Automatic export is off."
    }

    private func lastSyncDescription(for mappingID: UUID) -> String {
        guard let date = lastSyncDates[mappingID] else { return "Last successful sync: never" }
        return "Last successful sync: \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    private func refreshLastSyncDates() {
        var dates: [UUID: Date] = [:]
        for mapping in configuration.mappings where !mapping.destinationPath.isEmpty {
            let checkpoint = URL(fileURLWithPath: mapping.destinationPath, isDirectory: true)
                .appending(path: ".\(mapping.id.uuidString).last-successful-run.txt")
            if let attributes = try? FileManager.default.attributesOfItem(atPath: checkpoint.path),
               let modifiedAt = attributes[.modificationDate] as? Date {
                dates[mapping.id] = modifiedAt
            }
        }
        lastSyncDates = dates
    }

    private func refreshStatus() {
        scheduleIsLoaded = LaunchAgentScheduler.isLoaded()
        refreshLastSyncDates()
    }

    private func addMapping() {
        configuration.mappings.append(MailboxMapping(
            label: draftLabel,
            accountName: draftAccount,
            mailboxName: draftMailbox,
            destinationPath: draftDestination
        ))
        draftLabel = ""
        draftAccount = ""
        draftMailbox = ""
        draftDestination = ""
        isAddingMapping = false
    }

    private func removeMapping(_ id: UUID) {
        configuration.mappings.removeAll { $0.id == id }
        editingMappingIDs.remove(id)
    }

    private func chooseFolder(for mapping: Binding<MailboxMapping>) {
        chooseFolder { mapping.wrappedValue.destinationPath = $0.path }
    }

    private func chooseFolder(onSelect: (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        if panel.runModal() == .OK, let url = panel.url {
            onSelect(url)
        }
    }

    private func saveConfiguration(_ newValue: AppConfiguration) {
        do {
            try ConfigurationStore.save(newValue)
            statusMessage = "Settings saved"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func updateSchedule() {
        do {
            try ConfigurationStore.save(configuration)
            try LaunchAgentScheduler.update(enabled: configuration.scheduleEnabled, frequency: configuration.frequency)
            scheduleIsLoaded = LaunchAgentScheduler.isLoaded()
            statusMessage = configuration.scheduleEnabled ? "Settings saved · schedule active" : "Settings saved · schedule off"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func runExport() {
        isRunning = true
        statusMessage = "Exporting messages from Apple Mail…"
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try MailExporter().run()
                DispatchQueue.main.async {
                    isRunning = false
                    statusMessage = "Export complete"
                    refreshLastSyncDates()
                }
            } catch {
                DispatchQueue.main.async {
                    isRunning = false
                    statusMessage = error.localizedDescription
                }
            }
        }
    }
}