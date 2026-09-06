import Foundation

enum TimedReminderSnoozeDuration: Int, CaseIterable, Hashable, Identifiable {
    case fiveMinutes = 5
    case tenMinutes = 10
    case twentyMinutes = 20

    var id: Self { self }
    var title: String { "\(rawValue)" }
}

struct SnoozedTimedReminder: Equatable, Identifiable {
    let id: UUID
    let reminder: TimedReminderItem
    let fireDate: Date

    init(
        id: UUID = UUID(),
        reminder: TimedReminderItem,
        fireDate: Date
    ) {
        self.id = id
        self.reminder = reminder
        self.fireDate = fireDate
    }
}

struct TimedReminderSnoozeQueue {
    private(set) var entries: [SnoozedTimedReminder] = []

    @discardableResult
    mutating func schedule(
        _ reminder: TimedReminderItem,
        after duration: TimedReminderSnoozeDuration,
        now: Date = Date()
    ) -> Date {
        let fireDate = now.addingTimeInterval(TimeInterval(duration.rawValue * 60))
        entries.append(
            SnoozedTimedReminder(reminder: reminder, fireDate: fireDate)
        )
        return fireDate
    }

    mutating func remindersDue(through date: Date) -> [TimedReminderItem] {
        let dueEntries = entries
            .filter { $0.fireDate <= date }
            .sorted { $0.fireDate < $1.fireDate }
        let dueIDs = Set(dueEntries.map(\.id))
        entries.removeAll { dueIDs.contains($0.id) }
        return dueEntries.map(\.reminder)
    }
}
