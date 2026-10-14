import Foundation
import SwiftUI

@main
struct EmailNotebookLMIntegrationApp: App {
    init() {
        guard CommandLine.arguments.contains("--run") else { return }

        do {
            try MailExporter().run()
            exit(EXIT_SUCCESS)
        } catch {
            fputs("Email export failed: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}