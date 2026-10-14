#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP_NAME="Email to NotebookLM.app"
APP_DIR="$PROJECT_DIR/dist/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
EXECUTABLE_NAME="EmailNotebookLMIntegration"

cd "$PROJECT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS"
cp ".build/release/$EXECUTABLE_NAME" "$CONTENTS_DIR/MacOS/$EXECUTABLE_NAME"

PLIST="$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleName string Email to NotebookLM" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Email to NotebookLM" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.caalvara.emailnotebooklmintegration" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $EXECUTABLE_NAME" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 1.0" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 14.0" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :NSAppleEventsUsageDescription string Email to NotebookLM reads Apple Mail messages for transcript and timecard reports." "$PLIST"
/usr/libexec/PlistBuddy -c "Add :NSCalendarsFullAccessUsageDescription string Email to NotebookLM reads calendar events to prepare timecard reports." "$PLIST"
/usr/libexec/PlistBuddy -c "Add :LSApplicationCategoryType string public.app-category.productivity" "$PLIST"

printf 'Created %s\n' "$APP_DIR"