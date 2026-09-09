import Combine
import Foundation

@MainActor
final class ConfigurationStore: ObservableObject {
    nonisolated static let storageKey = "app-configuration-v1"

    @Published var configuration: AppConfiguration {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let storageKey: String

    init(defaults: UserDefaults = .standard, storageKey: String = ConfigurationStore.storageKey) {
        self.defaults = defaults
        self.storageKey = storageKey

        guard
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(AppConfiguration.self, from: data)
        else {
            configuration = .initial
            return
        }
        configuration = decoded.sanitized()
    }

    func addItem() {
        configuration.items.append(
            ReminderItem(text: configuration.displayLanguage.localized("新的提醒"))
        )
    }

    func removeItem(id: ReminderItem.ID) {
        configuration.items.removeAll { $0.id == id }
    }

    func moveItem(id: ReminderItem.ID, offset: Int) {
        guard
            let source = configuration.items.firstIndex(where: { $0.id == id }),
            configuration.items.indices.contains(source + offset)
        else { return }

        configuration.items.swapAt(source, source + offset)
    }

    func toggleItemVisibility(id: ReminderItem.ID) {
        guard let index = configuration.items.firstIndex(where: { $0.id == id }) else { return }
        configuration.items[index].isVisible.toggle()
    }

    func addTimedReminder(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) {
        let components = calendar.dateComponents([.hour], from: now)
        configuration.timedReminders.append(
            TimedReminderItem(
                text: configuration.displayLanguage.localized("新的定时提醒"),
                hour: components.hour ?? 9,
                minute: 0
            )
        )
    }

    func removeTimedReminder(id: TimedReminderItem.ID) {
        configuration.timedReminders.removeAll { $0.id == id }
    }

    func timedReminders(usingBackgroundImageNamed imageName: String) -> [TimedReminderItem] {
        configuration.timedReminders.filter { $0.backgroundImageName == imageName }
    }

    func toggleTimedReminderWeekday(id: TimedReminderItem.ID, weekday: ReminderWeekday) {
        guard let index = configuration.timedReminders.firstIndex(where: { $0.id == id }) else { return }
        if configuration.timedReminders[index].selectedWeekdays.contains(weekday) {
            guard configuration.timedReminders[index].selectedWeekdays.count > 1 else { return }
            configuration.timedReminders[index].selectedWeekdays.remove(weekday)
        } else {
            configuration.timedReminders[index].selectedWeekdays.insert(weekday)
        }
    }

    func toggleTimedReminderMonthlyDay(id: TimedReminderItem.ID, day: MonthlyReminderDay) {
        guard let index = configuration.timedReminders.firstIndex(where: { $0.id == id }) else { return }
        if configuration.timedReminders[index].monthlyDays.contains(day) {
            guard configuration.timedReminders[index].monthlyDays.count > 1 else { return }
            configuration.timedReminders[index].monthlyDays.remove(day)
        } else {
            configuration.timedReminders[index].monthlyDays.insert(day)
        }
    }

    func selectResidentReminderPosition(_ position: ResidentReminderPosition) {
        var updatedConfiguration = configuration
        updatedConfiguration.residentReminderPosition = position
        updatedConfiguration.savedWindowOrigin = nil
        configuration = updatedConfiguration
    }

    func resetWindowPosition() {
        selectResidentReminderPosition(.topRight)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(configuration) else {
            assertionFailure("AppConfiguration should always be encodable")
            return
        }
        defaults.set(data, forKey: storageKey)
    }
}
