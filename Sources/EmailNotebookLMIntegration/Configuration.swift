import Foundation

struct MailboxMapping: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var label: String
    var accountName: String
    var mailboxName: String
    var destinationPath: String
}

enum ExportFrequency: String, CaseIterable, Codable, Identifiable {
    case every15Minutes
    case hourly
    case daily
    case weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .every15Minutes: "Every 15 minutes"
        case .hourly: "Hourly"
        case .daily: "Daily"
        case .weekly: "Weekly"
        }
    }

    var seconds: Int {
        switch self {
        case .every15Minutes: 900
        case .hourly: 3_600
        case .daily: 86_400
        case .weekly: 604_800
        }
    }
}

struct AppConfiguration: Codable, Equatable {
    var mappings: [MailboxMapping] = []
    var scheduleEnabled = false
    var frequency: ExportFrequency = .daily
}

enum ConfigurationStore {
    static let directory = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Application Support/EmailNotebookLMIntegration", directoryHint: .isDirectory)
    static let fileURL = directory.appending(path: "config.json")

    static func load() -> AppConfiguration {
        guard let data = try? Data(contentsOf: fileURL),
              let configuration = try? JSONDecoder().decode(AppConfiguration.self, from: data) else {
            return AppConfiguration()
        }
        return configuration
    }

    static func save(_ configuration: AppConfiguration) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(configuration).write(to: fileURL, options: .atomic)
    }
}