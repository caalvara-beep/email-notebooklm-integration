# Email to NotebookLM

A native macOS utility that exports messages from selected Apple Mail mailboxes into monthly UTF-8 text transcripts in local folders, including Google Drive sync folders.

## Build

Requires macOS 14 or later and Xcode Command Line Tools.

```sh
sh Scripts/build-app.sh
```

The app is created at `dist/Email to NotebookLM.app`. Move the app to a stable location such as `/Applications` before enabling automatic exports. The scheduled job points to the app's current location.

## Configure

1. Open **Email Sync**, choose **Add mailbox**, and create one mapping for each Apple Mail mailbox. Saved mappings stay compact; use **Edit** to change one.
2. Enter a mapping name, the Mail account name, the mailbox name, and choose its local destination folder. Google Drive destinations must be folders already present on this Mac.
3. Click **Run now** once. macOS will ask permission for the app to control Mail; allow it in Privacy & Security > Automation if prompted.
4. Enable automatic export and choose a frequency.

The first run imports existing messages. Later runs ask Mail only for messages received since the last successful run. Files are named `Mapping_Name_YYYY-MM.txt`; each mapping stores a hidden checkpoint and message-ID ledger in its destination folder. The ledger prevents duplicate exports if a run is interrupted. After upgrading from an older build, the first run performs one full scan to establish the checkpoint, then later runs are incremental.

Configuration and scheduler logs are stored under `~/Library/Application Support/EmailNotebookLMIntegration/`. Schedule changes take effect through a per-user `launchd` agent; the Mac must be awake and the user logged in for scheduled runs.

## Timecards

Choose **Timecards Reports** from the home screen, select a start and end date, then load activity. The app reads Calendar events and Apple Mail Sent mail for that period. macOS will ask for Calendar and Mail automation access. Calendar entries use their event duration; optional prep time is added to that duration. Sent messages start at 15 minutes and can be adjusted in 15-minute steps up to 120 minutes.

Projects are seeded from mailbox mapping names and include `Internal` and `Time-off`; edit or add projects in the Timecards view. Assign a project to every included event and sent message, or mark entries excluded, to generate the report. The report groups totals Sunday through Saturday by project, groups same-subject emails per day, previews in the app, and can be saved as a UTF-8 text file.

Calendar project assignments are saved by calendar-item series, so recurring events are pre-assigned on later loads. The report preview shows one weekly project-by-day table per week. Use a row's notes button to review or copy notes by day, or copy all notes for that project and week. Report generation shows progress before opening the preview.

## Mailbox names

Use the account and mailbox names as shown in Apple Mail. Mailbox names are currently matched within the selected account. Add separate mappings for mailboxes that should go to different destination folders.

## Sharing

This initial build is unsigned. Coworkers can build it from source with Xcode Command Line Tools. For a downloadable app, distribute a Developer ID-signed and notarized build so macOS Gatekeeper can verify it.