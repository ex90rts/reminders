import AppKit
import Combine

enum MenuItemImageVisibilityCompatibility {
    private static let preferredImageVisibilityKey = "preferredImageVisibility"
    private static let preferredImageVisibilitySetter = NSSelectorFromString("setPreferredImageVisibility:")
    private static let hiddenImageVisibilityRawValue = 2

    static func hideImage(for item: NSMenuItem) {
        item.image = nil
        guard item.responds(to: preferredImageVisibilitySetter) else { return }

        // This AppKit property is macOS 27-only. KVC preserves the behavior while
        // keeping the project compilable with the macOS 15 SDK used by GitHub Actions.
        item.setValue(hiddenImageVisibilityRawValue, forKey: preferredImageVisibilityKey)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ConfigurationStore()
    private var overlayController: OverlayWindowController?
    private var settingsController: SettingsWindowController?
    private var timedReminderAlertController: TimedReminderAlertController?
    private var timedReminderScheduler: TimedReminderScheduler?
    private var statusItem: NSStatusItem?
    private var settingsMenuItem: NSMenuItem?
    private var visibilityMenuItem: NSMenuItem?
    private var resetPositionMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?
    private var subscriptions: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let overlayController = OverlayWindowController(store: store)
        let settingsController = SettingsWindowController(
            store: store,
            resetPosition: { [weak overlayController] in overlayController?.resetPosition() },
            previewTimedReminder: { [weak self] reminder in
                self?.timedReminderAlertController?.enqueue([reminder])
            }
        )
        self.overlayController = overlayController
        self.settingsController = settingsController

        let backgroundImageStore = TimedReminderBackgroundImageStore.live
        let timedReminderAlertController = TimedReminderAlertController(
            backgroundImageProvider: { reminder in
                backgroundImageStore.image(named: reminder.backgroundImageName)
            },
            displayLanguageProvider: { [weak store] in
                store?.configuration.displayLanguage ?? .system
            }
        )
        let timedReminderScheduler = TimedReminderScheduler(store: store) { [weak timedReminderAlertController] reminders in
            timedReminderAlertController?.enqueueScheduled(reminders)
        }
        timedReminderAlertController.onSnooze = { [weak timedReminderScheduler] reminder, duration in
            timedReminderScheduler?.snooze(reminder, for: duration)
        }
        self.timedReminderAlertController = timedReminderAlertController
        self.timedReminderScheduler = timedReminderScheduler

        configureStatusMenu()
        observeConfiguration()
        timedReminderScheduler.start()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsController?.present()
        return true
    }

    @objc private func openSettings() {
        settingsController?.present()
    }

    @objc private func toggleOverlay() {
        store.configuration.isOverlayVisible.toggle()
    }

    @objc private func resetPosition() {
        overlayController?.resetPosition()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func configureStatusMenu() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = statusBarImage()
        statusItem.button?.toolTip = localized("清醒贴")

        let menu = NSMenu()
        let settingsItem = menuItem(localized("打开设置…"), action: #selector(openSettings))
        MenuItemImageVisibilityCompatibility.hideImage(for: settingsItem)
        menu.addItem(settingsItem)
        settingsMenuItem = settingsItem

        let visibilityItem = menuItem(localized("显示常驻提醒"), action: #selector(toggleOverlay))
        visibilityItem.state = store.configuration.isOverlayVisible ? .on : .off
        menu.addItem(visibilityItem)
        visibilityMenuItem = visibilityItem

        let resetPositionItem = menuItem(localized("恢复常驻提醒位置"), action: #selector(resetPosition))
        menu.addItem(resetPositionItem)
        resetPositionMenuItem = resetPositionItem
        menu.addItem(.separator())
        let quitItem = menuItem(localized("退出清醒贴"), action: #selector(quit), key: "q")
        menu.addItem(quitItem)
        quitMenuItem = quitItem

        statusItem.menu = menu
        self.statusItem = statusItem
    }

    private func statusBarImage() -> NSImage? {
        if
            let iconURL = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "svg"),
            let image = NSImage(contentsOf: iconURL)
        {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            image.accessibilityDescription = localized("清醒贴")
            return image
        }

        return NSImage(
            systemSymbolName: "note.text",
            accessibilityDescription: localized("清醒贴")
        )
    }

    private func observeConfiguration() {
        store.$configuration
            .map(\.isOverlayVisible)
            .removeDuplicates()
            .sink { [weak self] isVisible in
                self?.visibilityMenuItem?.state = isVisible ? .on : .off
            }
            .store(in: &subscriptions)

        store.$configuration
            .map(\.displayLanguage)
            .removeDuplicates()
            .sink { [weak self] language in
                self?.updateLocalizedMenuContent(language: language)
            }
            .store(in: &subscriptions)
    }

    private func updateLocalizedMenuContent(language: AppLanguage) {
        let appName = language.localized("清醒贴")
        statusItem?.button?.toolTip = appName
        statusItem?.button?.image?.accessibilityDescription = appName
        settingsMenuItem?.title = language.localized("打开设置…")
        visibilityMenuItem?.title = language.localized("显示常驻提醒")
        resetPositionMenuItem?.title = language.localized("恢复常驻提醒位置")
        quitMenuItem?.title = language.localized("退出清醒贴")
    }

    private func localized(_ key: String, _ arguments: CVarArg...) -> String {
        AppLocalization.localized(
            key,
            language: store.configuration.displayLanguage,
            arguments: arguments
        )
    }

    private func menuItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }
}
