import AppKit
import SwiftUI

private final class TimedReminderPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class TimedReminderAlertController {
    private static let scheduledDuplicateWindow: TimeInterval = 60

    private let panel: TimedReminderPanel
    private let model: TimedReminderPopupModel
    private var queuedReminders: [TimedReminderItem] = []
    private var currentReminder: TimedReminderItem?
    private var countdownTimer: Timer?
    private var currentSound: NSSound?
    private var latestScheduledEnqueueDates: [TimedReminderItem.ID: Date] = [:]
    private let backgroundImageProvider: (TimedReminderItem) -> NSImage?
    private let displayLanguageProvider: () -> AppLanguage
    var onSnooze: (TimedReminderItem, TimedReminderSnoozeDuration) -> Void = { _, _ in }

    init(
        backgroundImageProvider: @escaping (TimedReminderItem) -> NSImage? = { _ in nil },
        displayLanguageProvider: @escaping () -> AppLanguage = { .system }
    ) {
        let panel = TimedReminderPanel(
            contentRect: CGRect(origin: .zero, size: TimedReminderPopupLayout.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let model = TimedReminderPopupModel()
        self.panel = panel
        self.model = model
        self.backgroundImageProvider = backgroundImageProvider
        self.displayLanguageProvider = displayLanguageProvider

        model.dismiss = { [weak self] in
            self?.dismissCurrentReminder()
        }
        model.snooze = { [weak self] duration in
            self?.snoozeCurrentReminder(for: duration)
        }

        panel.contentViewController = NSHostingController(
            rootView: TimedReminderPopupView(model: model)
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .alertPanel
    }

    func enqueue(_ reminders: [TimedReminderItem]) {
        queuedReminders.append(contentsOf: reminders)
        presentNextReminderIfNeeded()
    }

    func enqueueScheduled(_ reminders: [TimedReminderItem], now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-Self.scheduledDuplicateWindow)
        latestScheduledEnqueueDates = latestScheduledEnqueueDates.filter { $0.value > cutoff }

        let newReminders = reminders.filter { reminder in
            guard latestScheduledEnqueueDates[reminder.id] == nil else { return false }
            latestScheduledEnqueueDates[reminder.id] = now
            return true
        }
        enqueue(newReminders)
    }

    private func presentNextReminderIfNeeded() {
        guard currentReminder == nil, !queuedReminders.isEmpty else { return }

        let reminder = queuedReminders.removeFirst()
        currentReminder = reminder
        model.displayLanguage = displayLanguageProvider()
        model.text = reminder.text.isEmpty
            ? model.displayLanguage.localized("未填写提醒")
            : reminder.text
        model.secondsRemaining = TimedReminderPopupModel.dismissalSeconds
        model.snoozeDuration = .fiveMinutes
        model.backgroundImage = backgroundImageProvider(reminder)
        model.isPresented = true

        centerPanelOnActiveScreen()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        playSound(named: reminder.soundName)
        startCountdown()
    }

    private func startCountdown() {
        countdownTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.countdownDidTick()
            }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    private func countdownDidTick() {
        model.secondsRemaining -= 1
        if model.secondsRemaining <= 0 {
            dismissCurrentReminder()
        }
    }

    private func dismissCurrentReminder() {
        guard currentReminder != nil else { return }
        countdownTimer?.invalidate()
        countdownTimer = nil
        currentSound?.stop()
        currentSound = nil
        model.isPresented = false
        panel.orderOut(nil)
        currentReminder = nil
        presentNextReminderIfNeeded()
    }

    private func snoozeCurrentReminder(for duration: TimedReminderSnoozeDuration) {
        guard let currentReminder else { return }
        onSnooze(currentReminder, duration)
        dismissCurrentReminder()
    }

    private func playSound(named name: String?) {
        currentSound?.stop()
        currentSound = SystemSoundLibrary.sound(named: name)
        currentSound?.loops = true
        currentSound?.currentTime = 0
        currentSound?.play()
    }

    private func centerPanelOnActiveScreen() {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else { return }

        let origin = CGPoint(
            x: visibleFrame.midX - TimedReminderPopupLayout.windowSize.width / 2,
            y: visibleFrame.midY - TimedReminderPopupLayout.windowSize.height / 2
        )
        panel.setFrame(CGRect(origin: origin, size: TimedReminderPopupLayout.windowSize), display: true)
    }
}
