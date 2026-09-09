# Reminders project instructions

## Project manifests

`Package.swift` is the primary build and test manifest. It defines the macOS 15 deployment target, the `Reminders` executable target, the `RemindersTests` test target, and the Swift language mode. Use the script commands below for normal compilation and testing; they invoke SwiftPM and therefore read `Package.swift` directly.

Use `清醒贴.xcodeproj` only when a task specifically needs Xcode scheme, native app-target, or Xcode resource-build validation. Keep target or source-list changes consistent with both manifests when they affect the native Xcode project.

## Build and test environment

The system-selected Command Line Tools may contain a Swift compiler and macOS SDK with mismatched patch versions. Do not use bare `swift` build or test commands for this project.

Run all commands below from the `reminders` directory. The build script selects Xcode beta, invokes Swift through `xcrun`, keeps compiler/package caches at absolute paths under `.build`, and disables the SwiftPM sandbox.

Run the complete test suite:

```bash
./scripts/build-app.sh --test
```

For a focused test, append SwiftPM test options:

```bash
./scripts/build-app.sh --test --filter ConfigurationStoreTests/testName
```

If SwiftUI macros fail with `sandbox_apply: Operation not permitted` inside Codex, rerun the same script with system-sandbox approval. This is an execution-environment failure, not evidence of a source-code error.

The project also has a native Xcode project. Use this command when the task specifically requires validating the Xcode application and test targets:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -quiet \
  -project '清醒贴.xcodeproj' \
  -scheme '清醒贴' \
  -configuration Debug \
  -derivedDataPath "$PWD/.build/xcode-derived-data" \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Build the distributable app. Skip icon regeneration when icon sources have not changed:

```bash
./scripts/build-app.sh --skip-icons
```

By default, every successful app build increments the patch component of the current `CFBundleShortVersionString` (for example, `1.0.1` becomes `1.0.2`). Pass `--version x.y.z` only when an explicit semantic version is required. Test runs never change either version. Every successful app build writes `CFBundleVersion` as the current local timestamp in `YYYYMMDDHHmmss` format.

After packaging, verify `dist/Reminders.app` with `codesign --verify --deep --strict` before reporting a successful release build.

## Development completion

After every source-code change, do not stop at tests. Unless the user explicitly asks otherwise, complete the local delivery loop before reporting completion:

1. Run the complete test suite.
2. Build `dist/Reminders.app` with `./scripts/build-app.sh --skip-icons` when icon sources are unchanged.
3. Verify the packaged app's signature and embedded version.
4. Gracefully stop the currently running `com.webber.reminders` instance and launch the newly built app.
5. Confirm that the new process is running from this project's `dist/Reminders.app`.
