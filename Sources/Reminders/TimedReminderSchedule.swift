import Foundation

struct TimedReminderOccurrence: Equatable {
    let reminderID: TimedReminderItem.ID
    let date: Date
}

enum TimedReminderSchedule {
    static func occurrences(
        after startDate: Date,
        through endDate: Date,
        reminders: [TimedReminderItem],
        calendar: Calendar = .autoupdatingCurrent
    ) -> [TimedReminderOccurrence] {
        guard startDate < endDate else { return [] }

        return reminders.compactMap { reminder in
            nextOccurrence(after: startDate, for: reminder, calendar: calendar)
        }
        .filter { $0.date <= endDate }
        .sorted { $0.date < $1.date }
    }

    static func nextOccurrence(
        after date: Date,
        for reminder: TimedReminderItem,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TimedReminderOccurrence? {
        guard reminder.isEnabled else { return nil }

        if reminder.frequency == .hourlyInterval {
            return nextHourlyIntervalDate(after: date, for: reminder, calendar: calendar)
                .map { TimedReminderOccurrence(reminderID: reminder.id, date: $0) }
        }

        let weekdays: [ReminderWeekday?]
        switch reminder.frequency {
        case .hourlyInterval:
            preconditionFailure("Hourly intervals are handled before weekday matching")
        case .daily:
            weekdays = [nil]
        case .selectedWeekdays:
            weekdays = reminder.selectedWeekdays.map(Optional.some)
        }

        let nextDate = weekdays.compactMap { weekday -> Date? in
            var components = DateComponents()
            components.hour = reminder.hour
            components.minute = reminder.minute
            components.second = 0
            components.weekday = weekday?.rawValue
            return calendar.nextDate(
                after: date,
                matching: components,
                matchingPolicy: .nextTime,
                repeatedTimePolicy: .first,
                direction: .forward
            )
        }.min()

        return nextDate.map { TimedReminderOccurrence(reminderID: reminder.id, date: $0) }
    }

    private static func nextHourlyIntervalDate(
        after date: Date,
        for reminder: TimedReminderItem,
        calendar: Calendar
    ) -> Date? {
        let intervalHours = reminder.intervalHours.clamped(to: TimedReminderItem.intervalHoursRange)
        let today = calendar.startOfDay(for: date)

        if let todayStart = configuredStartTime(
            onDayContaining: today,
            for: reminder,
            calendar: calendar
        ) {
            var candidate = todayStart

            // At most 24 hourly candidates can belong to one calendar day.
            for _ in 0..<24 {
                guard calendar.isDate(candidate, inSameDayAs: today) else { break }
                if candidate > date {
                    return candidate
                }
                guard let nextCandidate = calendar.date(
                    byAdding: .hour,
                    value: intervalHours,
                    to: candidate
                ) else { break }
                candidate = nextCandidate
            }
        }

        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            return nil
        }
        return configuredStartTime(onDayContaining: tomorrow, for: reminder, calendar: calendar)
    }

    private static func configuredStartTime(
        onDayContaining day: Date,
        for reminder: TimedReminderItem,
        calendar: Calendar
    ) -> Date? {
        let startOfDay = calendar.startOfDay(for: day)
        guard let searchStart = calendar.date(byAdding: .second, value: -1, to: startOfDay) else {
            return nil
        }

        let candidate = calendar.nextDate(
            after: searchStart,
            matching: DateComponents(
                hour: reminder.hour,
                minute: reminder.minute,
                second: 0
            ),
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )

        guard let candidate, calendar.isDate(candidate, inSameDayAs: day) else {
            return nil
        }
        return candidate
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
