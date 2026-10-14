import AppKit
import Foundation

struct MailExporter {
    func run() throws {
        let configuration = ConfigurationStore.load()
        guard !configuration.mappings.isEmpty else {
            throw ExportError.noMappings
        }

        for mapping in configuration.mappings {
            try export(mapping)
        }
    }

    private func export(_ mapping: MailboxMapping) throws {
        guard !mapping.accountName.isEmpty,
              !mapping.mailboxName.isEmpty,
              !mapping.destinationPath.isEmpty else {
            throw ExportError.incompleteMapping(mapping.label)
        }

        let destination = URL(fileURLWithPath: mapping.destinationPath, isDirectory: true)
            .standardizedFileURL
        let ledger = destination.appending(path: ".\(mapping.id.uuidString).exported-ids.txt")
        let checkpoint = destination.appending(path: ".\(mapping.id.uuidString).last-successful-run.txt")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        guard let script = NSAppleScript(source: makeScript(
            mapping: mapping,
            destination: destination,
            ledger: ledger,
            checkpoint: checkpoint
        )) else {
            throw ExportError.scriptCreation
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            throw ExportError.appleScript(errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown Mail error")
        }
    }

    private func makeScript(mapping: MailboxMapping, destination: URL, ledger: URL, checkpoint: URL) -> String {
        let accountName = appleScriptString(mapping.accountName)
        let mailboxName = appleScriptString(mapping.mailboxName)
        let destinationPath = appleScriptString(destination.path)
        let ledgerPath = appleScriptString(ledger.path)
        let checkpointPath = appleScriptString(checkpoint.path)
        let filePrefix = appleScriptString(fileSafe(mapping.label.isEmpty ? mapping.mailboxName : mapping.label))

        return """
        on run
            set destinationPath to "\(destinationPath)"
            set ledgerPath to "\(ledgerPath)"
            set checkpointPath to "\(checkpointPath)"
            set filePrefix to "\(filePrefix)"
            do shell script "/bin/mkdir -p " & quoted form of destinationPath
            set exportedIds to {}
            try
                set ledgerFile to open for access (POSIX file ledgerPath)
                set ledgerText to read ledgerFile
                close access ledgerFile
                set exportedIds to paragraphs of ledgerText
            end try
            set lastRunDate to missing value
            try
                set checkpointFile to open for access (POSIX file checkpointPath)
                set checkpointText to read checkpointFile
                close access checkpointFile
                set lastRunDate to checkpointText as date
            end try

            with timeout of 600 seconds
            tell application "Mail"
                set targetAccount to missing value
                set mailAccounts to every account
                repeat with candidateAccount in mailAccounts
                    if (name of candidateAccount as text) is "\(accountName)" then
                        set targetAccount to contents of candidateAccount
                        exit repeat
                    end if
                    try
                        if (email addresses of candidateAccount) contains "\(accountName)" then
                            set targetAccount to contents of candidateAccount
                            exit repeat
                        end if
                    end try
                end repeat
                if targetAccount is missing value then
                    error "No Mail account matches the configured name or email address: \(accountName)"
                end if
                set targetMailbox to first mailbox of targetAccount whose name is "\(mailboxName)"
                set runStartedAt to current date
                if lastRunDate is missing value then
                    set allMessages to every message of targetMailbox
                else
                    set allMessages to every message of targetMailbox whose date received is greater than lastRunDate and date received is less than or equal to runStartedAt
                end if
                repeat with aMessage in allMessages
                    set messageId to (message id of aMessage) as text
                    if messageId is not in exportedIds then
                        set receivedAt to date received of aMessage
                        set messageYear to year of receivedAt as integer
                        set messageMonth to my twoDigits(month of receivedAt as integer)
                        set monthPath to destinationPath & "/" & filePrefix & "_" & messageYear & "-" & messageMonth & ".txt"
                        set messageText to "========================================" & return & ¬
                            "FROM: " & (sender of aMessage) & return & ¬
                            "DATE: " & (receivedAt as string) & return & ¬
                            "SUBJECT: " & (subject of aMessage) & return & ¬
                            "BODY:" & return & (content of aMessage) & return & return
                        my appendUtf8(messageText, monthPath)
                        my appendUtf8(messageId & return, ledgerPath)
                        set end of exportedIds to messageId
                    end if
                end repeat
                my writeUtf8(runStartedAt as string, checkpointPath)
            end tell
            end timeout
        end run

        on twoDigits(numberValue)
            if numberValue < 10 then return "0" & numberValue
            return numberValue as text
        end twoDigits

        on appendUtf8(theText, thePath)
            set outputFile to open for access (POSIX file thePath) with write permission
            try
                write theText to outputFile starting at eof as «class utf8»
                close access outputFile
            on error errorMessage
                try
                    close access outputFile
                end try
                error errorMessage
            end try
        end appendUtf8

        on writeUtf8(theText, thePath)
            set outputFile to open for access (POSIX file thePath) with write permission
            try
                set eof of outputFile to 0
                write theText to outputFile as «class utf8»
                close access outputFile
            on error errorMessage
                try
                    close access outputFile
                end try
                error errorMessage
            end try
        end writeUtf8
        """
    }

    private func appleScriptString(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private func fileSafe(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let words = value.components(separatedBy: allowed.inverted).filter { !$0.isEmpty }
        return words.isEmpty ? "mailbox" : words.joined(separator: "_")
    }
}

enum ExportError: LocalizedError {
    case noMappings
    case incompleteMapping(String)
    case scriptCreation
    case appleScript(String)

    var errorDescription: String? {
        switch self {
        case .noMappings:
            "Add at least one mailbox mapping before running an export."
        case .incompleteMapping(let label):
            "The mapping \"\(label)\" is missing an account, mailbox, or destination folder."
        case .scriptCreation:
            "Could not prepare the Apple Mail export script."
        case .appleScript(let message):
            message
        }
    }
}