import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Email tools")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("Choose a workflow")
                    .foregroundStyle(.secondary)

                NavigationLink {
                    EmailSyncView()
                } label: {
                    featureRow(title: "Email Sync", detail: "Export mailbox transcripts to Google Drive", icon: "envelope")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    TimecardsView()
                } label: {
                    featureRow(title: "Timecards Reports", detail: "Review sent email and calendar activity", icon: "clock")
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(28)
            .frame(minWidth: 680, minHeight: 500, alignment: .topLeading)
            .navigationTitle("Email to NotebookLM")
        }
    }

    private func featureRow(title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }
}