import AppKit
import Combine
import Foundation

@MainActor
final class TimedReminderScheduler {
    nonisolated static let deliveryHistoryStorageKey = "timed-reminder-delivery-history-v1"

    private enum Timing {
        static let heartbeatInterval: DispatchTimeInterval = .seconds(1)
        static let heartbeatLeeway: DispatchTimeInterval = .milliseconds(100)
        static let currentMinuteEpsilon: TimeInterval = 0.001
    }

    private let store: ConfigurationStore
    private let defaults: UserDefaults
    private let deliveryHistoryStorageKey: String
    private let onRemindersDue: ([TimedReminderItem]) -> Void
    private var configurationSubscription: AnyCancellable?
    private var wakeObserver: NSObjectProtocol?
    private var heartbeat: DispatchSourceTimer?
    private var lastCheckDate: Date?
    private var deliveredOccurrenceDates: [TimedReminderItem.ID: Date] = [:]
    private var snoozeQueue = TimedReminderSnoozeQueue()

    init(
        store: ConfigurationStore,
        defaults: UserDefaults = .standard,
        deliveryHistoryStorageKey: String = TimedReminderScheduler.deliveryHistoryStorageKey,
        onRemindersDue: @escaping ([TimedReminderItem]) -> Void
    ) {
        self.store = store
        self.defaults = defaults
        self.deliveryHistoryStorageKey = deliveryHistoryStorageKey
        self.onRemindersDue = onRemindersDue
        deliveredOccurrenceDates = loadDeliveryHistory()
    }

    func start() {
        guard configurationSubscription == nil else { return }

        lastCheckDate = Date()
        configurationSubscription = store.$configuration
            .map(\.timedReminders)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.configurationDidChange()
            }

        startHeartbeat()
        observeWake()
    }

    func snooze(
        _ reminder: TimedReminderItem,
        for duration: TimedReminderSnoozeDuration,
        now: Date = Date()
    ) {
        snoozeQueue.schedule(reminder, after: duration, now: now)
    }

    private func startHeartbeat() {
        let heartbeat = DispatchSource.makeTimerSource(queue: .main)
        heartbeat.schedule(
            deadline: .now() + Timing.heartbeatInterval,
            repeating: Timing.heartbeatInterval,
            leeway: Timing.heartbeatLeeway
        )
        heartbeat.setEventHandler { [weak self] in
            self?.heartbeatDidFire()
        }
        heartbeat.resume()
        self.heartbeat = heartbeat
    }

    private func heartbeatDidFire() {
        let now = Date()
        let previousCheck = lastCheckDate ?? now.addingTimeInterval(-1)
        lastCheckDate = now

        if previousCheck < now {
            deliverOccurrences(after: previousCheck, through: now)
        } else {
            checkCurrentMinute(at: now)
        }
        deliverSnoozedReminders(through: now)
    }

    private func configurationDidChange() {
        mergePersistedDeliveryHistory()
        let validIDs = Set(store.configuration.timedReminders.map(\.id))
        deliveredOccurrenceDates = deliveredOccurrenceDates.filter { validIDs.contains($0.key) }
        persistDeliveryHistory()
        checkCurrentMinute(at: Date())
    }

    private func checkCurrentMinute(at date: Date) {
        let calendar = Calendar.autoupdatingCurrent
        guard let minute = calendar.dateInterval(of: .minute, for: date) else { return }
        deliverOccurrences(
            after: minute.start.addingTimeInterval(-Timing.currentMinuteEpsilon),
            through: date,
            calendar: calendar
        )
    }

    private func deliverOccurrences(
        after startDate: Date,
        through endDate: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        mergePersistedDeliveryHistory()
        let occurrences = TimedReminderSchedule.occurrences(
            after: startDate,
            through: endDate,
            reminders: store.configuration.timedReminders,
            calendar: calendar
        )
        let newOccurrences = occurrences.filter { occurrence in
            guard let deliveredDate = deliveredOccurrenceDates[occurrence.reminderID] else {
                return true
            }
            return deliveredDate < occurrence.date
        }
        guard !newOccurrences.isEmpty else { return }

        for occurrence in newOccurrences {
            deliveredOccurrenceDates[occurrence.reminderID] = occurrence.date
        }
        persistDeliveryHistory()
        let dueIDs = Set(newOccurrences.map(\.reminderID))
        let dueReminders = store.configuration.timedReminders.filter { reminder in
            reminder.isEnabled && dueIDs.contains(reminder.id)
        }
        if !dueReminders.isEmpty {
            onRemindersDue(dueReminders)
        }
    }

    private func loadDeliveryHistory() -> [TimedReminderItem.ID: Date] {
        guard let data = defaults.data(forKey: deliveryHistoryStorageKey) else { return [:] }
        return (try? JSONDecoder().decode([TimedReminderItem.ID: Date].self, from: data)) ?? [:]
    }

    private func mergePersistedDeliveryHistory() {
        for (id, date) in loadDeliveryHistory() {
            if deliveredOccurrenceDates[id].map({ $0 < date }) ?? true {
                deliveredOccurrenceDates[id] = date
            }
        }
    }

    private func persistDeliveryHistory() {
        guard let data = try? JSONEncoder().encode(deliveredOccurrenceDates) else {
            assertionFailure("Timed reminder delivery history should always be encodable")
            return
        }
        defaults.set(data, forKey: deliveryHistoryStorageKey)
    }

    private func deliverSnoozedReminders(through date: Date) {
        let reminders = snoozeQueue.remindersDue(through: date)
        if !reminders.isEmpty {
            onRemindersDue(reminders)
        }
    }

    private func observeWake() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.heartbeatDidFire()
            }
        }
    }

    deinit {
        heartbeat?.setEventHandler {}
        heartbeat?.cancel()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }
}
