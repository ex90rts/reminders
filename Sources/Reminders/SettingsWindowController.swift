import AppKit
import Combine
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private var languageSubscription: AnyCancellable?

    init(
        store: ConfigurationStore,
        resetPosition: @escaping () -> Void,
        previewTimedReminder: @escaping (TimedReminderItem) -> Void
    ) {
        let content = SettingsView(
            store: store,
            resetPosition: resetPosition,
            previewTimedReminder: previewTimedReminder
        )
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 760, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let hostingController = NSHostingController(rootView: content)
        window.title = store.configuration.displayLanguage.localized("清醒贴设置")
        window.contentViewController = hostingController
        // Match the SwiftUI minimum in content coordinates, excluding the title bar.
        window.contentMinSize = CGSize(width: 720, height: 560)
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("settings-window")
        let restoredContentSize = window.contentRect(forFrameRect: window.frame).size
        if restoredContentSize.width < window.contentMinSize.width
            || restoredContentSize.height < window.contentMinSize.height {
            window.setContentSize(CGSize(
                width: max(restoredContentSize.width, window.contentMinSize.width),
                height: max(restoredContentSize.height, window.contentMinSize.height)
            ))
        }

        super.init(window: window)
        window.delegate = self
        languageSubscription = store.$configuration
            .map(\.displayLanguage)
            .removeDuplicates()
            .sink { [weak window] language in
                window?.title = language.localized("清醒贴设置")
            }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
