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

## Sharing with coworkers

The app can be shared internally without signing or notarization. Recipients need a Mac running macOS 14 or later, Apple Mail, and access to their own Calendar data. They do not need Xcode or Swift installed to run the packaged app.

1. Build the app on a Mac with Xcode Command Line Tools: `sh Scripts/build-app.sh`.
2. From the project folder, create a ZIP that preserves the app bundle:

	```sh
	ditto -c -k --sequesterRsrc --keepParent "dist/Email to NotebookLM.app" "dist/Email-to-NotebookLM-macOS.zip"
	```

3. Share `dist/Email-to-NotebookLM-macOS.zip` using an organization-approved file-sharing location. The app is unsigned, so share it only with people who trust the source.
4. On the recipient's Mac, unzip the file and move the app to `~/Applications` or `/Applications`. Keep it at that location after enabling automatic export; the scheduled job points to the app's path.
5. On first launch, Control-click the app and choose **Open**, then confirm **Open** in the macOS warning. If macOS still blocks it, try opening it once, then look for **Open Anyway** under System Settings > Privacy & Security. Only approve an app received from a trusted source.
6. The recipient opens the app, configures their own Mail and destination folders, then grants Mail and Calendar permissions when prompted.

The ZIP is not signed or notarized. Notarization is optional for a small internal trial but removes most first-launch Gatekeeper warnings when distributing broadly.

## FAQ

### How does the app read email?

Email Sync uses macOS Apple Events to ask Apple Mail for messages in the account and mailbox selected in each mapping. It writes the sender, received date, subject, and message body to monthly UTF-8 text files in the chosen local destination. The Timecards view reads only sent-message IDs, sent dates, and subject lines within the selected period; it does not include message bodies in timecard reports.

The app has no email server or cloud backend. If a destination is inside Google Drive, Google Drive for desktop may sync the files according to the user's organization settings.

### How does Calendar access work?

The Timecards view uses Apple's EventKit API to read calendar events in the selected date range. It uses event titles, start/end times, and calendar-item identifiers to calculate duration and remember project assignments for recurring events. It does not modify Calendar events. Saved project assignments are stored locally under `~/Library/Application Support/EmailNotebookLMIntegration/`.

### What permissions are required?

- A standard macOS user account is sufficient. Installing in `~/Applications` does not normally require administrator access; `/Applications` may require it.
- In System Settings > Privacy & Security > Automation, allow **Email to NotebookLM** to control **Mail**.
- In System Settings > Privacy & Security > Calendars, allow **Email to NotebookLM** to access calendars.
- The chosen destination folder must be writable by the user. For Google Drive, use a local folder available on that Mac.

Each coworker grants permissions on their own Mac. The app does not need the sender's Apple ID password or Google Drive credentials.

### Why does macOS warn that the app cannot be checked?

This shared build is unsigned and unnotarized. If the app came from a trusted coworker, Control-click it and choose **Open**. If needed, use **Open Anyway** in Privacy & Security after the first attempt. Do not bypass the warning for an app whose source you cannot verify.

### Mail says it cannot find an account or mailbox. What should I check?

Use the Mail account name or email address as shown in Apple Mail, and enter the mailbox name exactly as it appears under that account. For Timecards, the Sent folder is detected by its standard name or Mail's mailbox type. Confirm the account is enabled in Apple Mail.

### Why are there no Calendar events or sent emails?

Check the selected date range and confirm that events or sent messages exist in that period. Then check the Calendar and Automation permissions above. After changing permissions, quit and reopen the app before loading activity again.

### Why is automatic export not running?

Open Email Sync and click **Check status**. The app must remain at the same installed path, automatic export must be enabled, and the user must be logged in. Scheduled jobs run only while the Mac is awake. Check `~/Library/Application Support/EmailNotebookLMIntegration/Logs/stderr.log` for errors.

### Why can the app not save a transcript or report?

Confirm the destination folder exists and is writable. Google Drive folders must be available locally and signed in on that Mac. The timecard report's **Download text file** action opens a save dialog; choose a folder where the user can write.