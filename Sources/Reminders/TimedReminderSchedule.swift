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

        switch reminder.frequency {
        case .hourlyInterval:
            return nextHourlyIntervalDate(after: date, for: reminder, calendar: calendar)
                .map { TimedReminderOccurrence(reminderID: reminder.id, date: $0) }
        case .monthly:
            return nextMonthlyDate(after: date, for: reminder, calendar: calendar)
                .map { TimedReminderOccurrence(reminderID: reminder.id, date: $0) }
        case .specificDate:
            guard let specificDate = reminder.specificDate, specificDate > date else { return nil }
            return TimedReminderOccurrence(reminderID: reminder.id, date: specificDate)
        case .daily, .selectedWeekdays:
            break
        }

        let weekdays: [ReminderWeekday?]
        switch reminder.frequency {
        case .hourlyInterval:
            preconditionFailure("Hourly intervals are handled before weekday matching")
        case .daily:
            weekdays = [nil]
        case .selectedWeekdays:
            weekdays = reminder.selectedWeekdays.map(Optional.some)
        case .monthly:
            preconditionFailure("Monthly reminders are handled before weekday matching")
        case .specificDate:
            preconditionFailure("Specific dates are handled before weekday matching")
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

    private static func nextMonthlyDate(
        after date: Date,
        for reminder: TimedReminderItem,
        calendar: Calendar
    ) -> Date? {
        var monthComponents = calendar.dateComponents([.era, .year, .month], from: date)
        monthComponents.day = 1
        guard let currentMonthStart = calendar.date(from: monthComponents) else { return nil }

        // Every numbered Gregorian day occurs within this window, including February leap-day cases.
        for monthOffset in 0..<24 {
            guard
                let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: currentMonthStart),
                let dayRange = calendar.range(of: .day, in: .month, for: monthStart)
            else { continue }

            let nextCandidate = Set(
                reminder.monthlyDays.compactMap { $0.resolvedDay(in: dayRange) }
            )
            .sorted()
            .compactMap { day -> Date? in
                guard let dayDate = calendar.date(
                    byAdding: .day,
                    value: day - dayRange.lowerBound,
                    to: monthStart
                ) else { return nil }

                return configuredStartTime(
                    onDayContaining: dayDate,
                    for: reminder,
                    calendar: calendar
                )
            }
            .first { $0 > date }

            if let nextCandidate {
                return nextCandidate
            }
        }
        return nil
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
