import Foundation

enum LaunchAgentScheduler {
    private static let label = "com.caalvara.emailnotebooklmintegration"
    private static let agentURL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/LaunchAgents/\(label).plist")

    static func update(enabled: Bool, frequency: ExportFrequency) throws {
        if enabled {
            try install(frequency: frequency)
        } else {
            try remove()
        }
    }

    private static func install(frequency: ExportFrequency) throws {
        let executableURL = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
        let properties: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executableURL.path, "--run"],
            "RunAtLoad": true,
            "StartInterval": frequency.seconds,
            "StandardOutPath": logURL("stdout.log").path,
            "StandardErrorPath": logURL("stderr.log").path
        ]

        try FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: logURL("stdout.log").deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: properties, format: .xml, options: 0)
        try data.write(to: agentURL, options: .atomic)
        try launchctl(["bootout", "gui/\(getuid())", agentURL.path], ignoringFailure: true)
        try launchctl(["bootstrap", "gui/\(getuid())", agentURL.path])
    }

    private static func remove() throws {
        guard FileManager.default.fileExists(atPath: agentURL.path) else { return }
        try launchctl(["bootout", "gui/\(getuid())", agentURL.path], ignoringFailure: true)
        try FileManager.default.removeItem(at: agentURL)
    }

    private static func launchctl(_ arguments: [String], ignoringFailure: Bool = false) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 && !ignoringFailure {
            throw SchedulerError.launchctlFailed
        }
    }

    private static func logURL(_ name: String) -> URL {
        ConfigurationStore.directory.appending(path: "Logs", directoryHint: .isDirectory).appending(path: name)
    }
}

enum SchedulerError: LocalizedError {
    case launchctlFailed

    var errorDescription: String? {
        "Could not update the macOS background schedule. Try turning the schedule off and on again."
    }
}