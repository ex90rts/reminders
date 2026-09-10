import AppKit
import XCTest
@testable import Reminders

@MainActor
final class ConfigurationStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "RemindersTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testNewStoreUsesUsefulDefaults() {
        let store = ConfigurationStore(defaults: defaults, storageKey: "test")

        XCTAssertEqual(store.configuration.items.count, 3)
        XCTAssertTrue(store.configuration.timedReminders.isEmpty)
        XCTAssertEqual(store.configuration.reminderFontSize, AppConfiguration.defaultReminderFontSize)
        XCTAssertEqual(store.configuration.reminderWidth, AppConfiguration.defaultReminderWidth)
        XCTAssertTrue(store.configuration.isAlwaysOnTop)
        XCTAssertTrue(store.configuration.isOverlayVisible)
        XCTAssertEqual(store.configuration.residentReminderPosition, .topRight)
        XCTAssertEqual(store.configuration.displayLanguage, .system)
        XCTAssertEqual(TimedReminderPopupModel.dismissalSeconds, 30)
    }

    func testSupportedSystemLanguagesResolveToExpectedDisplayLanguage() {
        XCTAssertEqual(
            AppLanguage.resolve(preferredLanguages: ["zh-Hans-CN"]),
            .simplifiedChinese
        )
        XCTAssertEqual(
            AppLanguage.resolve(preferredLanguages: ["zh-Hant-TW"]),
            .traditionalChinese
        )
        XCTAssertEqual(
            AppLanguage.resolve(preferredLanguages: ["zh-HK"]),
            .traditionalChinese
        )
        XCTAssertEqual(
            AppLanguage.resolve(preferredLanguages: ["en-US"]),
            .englishUS
        )
        XCTAssertEqual(
            AppLanguage.resolve(preferredLanguages: ["fr-FR"]),
            .englishUS
        )
        XCTAssertEqual(
            AppLanguage.resolve(preferredLanguages: []),
            .englishUS
        )
    }

    func testUnknownPersistedDisplayLanguageFallsBackToSystem() throws {
        let language = try JSONDecoder().decode(
            AppLanguage.self,
            from: Data("\"future-language\"".utf8)
        )

        XCTAssertEqual(language, .system)
    }

    func testTimedReminderPopupShadowHasEnoughFadeOutSpace() {
        let requiredFadeOutSpace = TimedReminderPopupLayout.ambientShadowRadius * 2
            + TimedReminderPopupLayout.ambientShadowOffsetY

        XCTAssertGreaterThanOrEqual(
            TimedReminderPopupLayout.shadowPadding,
            requiredFadeOutSpace
        )
    }

    func testReminderBellAnimationRepeatsAndIncludesRestPhase() {
        let movingTime = 0.07
        let movingAngle = ReminderBellAnimation.angle(at: movingTime)

        XCTAssertNotEqual(movingAngle, 0, accuracy: 0.001)
        XCTAssertEqual(
            ReminderBellAnimation.angle(
                at: movingTime + ReminderBellAnimation.cycleDuration
            ),
            movingAngle,
            accuracy: 0.001
        )
        XCTAssertEqual(
            ReminderBellAnimation.angle(
                at: ReminderBellAnimation.activeDuration + 0.1
            ),
            0,
            accuracy: 0.001
        )
    }

    func testConfigurationPersistsAcrossStoreInstances() {
        var firstStore: ConfigurationStore? = ConfigurationStore(defaults: defaults, storageKey: "test")
        firstStore?.configuration.items[0].text = "先做最重要的事"
        firstStore?.configuration.items[0].isVisible = false
        firstStore?.configuration.reminderFontSize = 24
        firstStore?.configuration.reminderWidth = 480
        firstStore?.configuration.timedReminders = [
            TimedReminderItem(
                text: "喝水",
                hour: 9,
                minute: 30,
                backgroundImageName: "background.png"
            )
        ]
        firstStore?.configuration.isAlwaysOnTop = false
        firstStore?.configuration.displayLanguage = .traditionalChinese
        firstStore = nil

        let restoredStore = ConfigurationStore(defaults: defaults, storageKey: "test")
        XCTAssertEqual(restoredStore.configuration.items[0].text, "先做最重要的事")
        XCTAssertFalse(restoredStore.configuration.items[0].isVisible)
        XCTAssertEqual(restoredStore.configuration.reminderFontSize, 24)
        XCTAssertEqual(restoredStore.configuration.reminderWidth, 480)
        XCTAssertEqual(restoredStore.configuration.timedReminders.first?.backgroundImageName, "background.png")
        XCTAssertFalse(restoredStore.configuration.isAlwaysOnTop)
        XCTAssertEqual(restoredStore.configuration.displayLanguage, .traditionalChinese)
    }

    func testLegacyConfigurationUsesNewFieldDefaults() throws {
        let initialData = try JSONEncoder().encode(AppConfiguration.initial)
        var legacyJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: initialData) as? [String: Any]
        )
        legacyJSON.removeValue(forKey: "reminderFontSize")
        legacyJSON.removeValue(forKey: "reminderWidth")
        legacyJSON.removeValue(forKey: "timedReminderBackgroundImageName")
        legacyJSON.removeValue(forKey: "timedReminders")
        legacyJSON.removeValue(forKey: "residentReminderPosition")
        legacyJSON.removeValue(forKey: "displayLanguage")
        var legacyItems = try XCTUnwrap(legacyJSON["items"] as? [[String: Any]])
        for index in legacyItems.indices {
            legacyItems[index].removeValue(forKey: "isVisible")
        }
        legacyJSON["items"] = legacyItems
        defaults.set(try JSONSerialization.data(withJSONObject: legacyJSON), forKey: "test")

        let store = ConfigurationStore(defaults: defaults, storageKey: "test")

        XCTAssertEqual(store.configuration.reminderFontSize, AppConfiguration.defaultReminderFontSize)
        XCTAssertEqual(store.configuration.reminderWidth, AppConfiguration.defaultReminderWidth)
        XCTAssertTrue(store.configuration.timedReminders.allSatisfy { $0.backgroundImageName == nil })
        XCTAssertEqual(store.configuration.residentReminderPosition, .topRight)
        XCTAssertEqual(store.configuration.displayLanguage, .system)
        XCTAssertTrue(store.configuration.items.allSatisfy(\.isVisible))
        XCTAssertTrue(store.configuration.timedReminders.isEmpty)
    }

    func testTimedRemindersPersistAcrossStoreInstances() {
        var firstStore: ConfigurationStore? = ConfigurationStore(defaults: defaults, storageKey: "test")
        firstStore?.configuration.timedReminders = [
            TimedReminderItem(
                text: "起来活动",
                frequency: .selectedWeekdays,
                selectedWeekdays: [.monday, .wednesday, .friday],
                hour: 15,
                minute: 30,
                intervalHours: 4,
                soundName: "Glass",
                autoCloseEnabled: true,
                backgroundImageName: "builtin:alarm-bg-02.jpg"
            )
        ]
        firstStore = nil

        let restoredStore = ConfigurationStore(defaults: defaults, storageKey: "test")
        XCTAssertEqual(restoredStore.configuration.timedReminders.count, 1)
        XCTAssertEqual(restoredStore.configuration.timedReminders[0].text, "起来活动")
        XCTAssertEqual(restoredStore.configuration.timedReminders[0].selectedWeekdays, [.monday, .wednesday, .friday])
        XCTAssertEqual(restoredStore.configuration.timedReminders[0].hour, 15)
        XCTAssertEqual(restoredStore.configuration.timedReminders[0].minute, 30)
        XCTAssertEqual(restoredStore.configuration.timedReminders[0].intervalHours, 4)
        XCTAssertEqual(restoredStore.configuration.timedReminders[0].soundName, "Glass")
        XCTAssertTrue(restoredStore.configuration.timedReminders[0].autoCloseEnabled)
        XCTAssertEqual(
            restoredStore.configuration.timedReminders[0].backgroundImageName,
            "builtin:alarm-bg-02.jpg"
        )
    }

    func testSpecificDateTimedReminderPersistsAcrossStoreInstances() throws {
        let calendar = utcGregorianCalendar()
        let targetDate = try makeDate(2026, 10, 8, 14, 25, calendar: calendar)
        var firstStore: ConfigurationStore? = ConfigurationStore(defaults: defaults, storageKey: "test")
        firstStore?.configuration.timedReminders = [
            TimedReminderItem(
                text: "单次会议",
                frequency: .specificDate,
                hour: 14,
                minute: 25,
                specificDate: targetDate
            )
        ]
        firstStore = nil

        let restoredStore = ConfigurationStore(defaults: defaults, storageKey: "test")

        XCTAssertEqual(restoredStore.configuration.timedReminders.first?.frequency, .specificDate)
        XCTAssertEqual(restoredStore.configuration.timedReminders.first?.specificDate, targetDate)
    }

    func testMonthlyTimedReminderPersistsAcrossStoreInstances() {
        var firstStore: ConfigurationStore? = ConfigurationStore(defaults: defaults, storageKey: "test")
        firstStore?.configuration.timedReminders = [
            TimedReminderItem(
                text: "月末复盘",
                frequency: .monthly,
                monthlyDays: [.day(15), .lastDay],
                hour: 20,
                minute: 30
            )
        ]
        firstStore = nil

        let restoredStore = ConfigurationStore(defaults: defaults, storageKey: "test")

        XCTAssertEqual(restoredStore.configuration.timedReminders.first?.frequency, .monthly)
        XCTAssertEqual(restoredStore.configuration.timedReminders.first?.monthlyDays, [.day(15), .lastDay])
    }

    func testLegacyTimedReminderUsesDefaultIntervalHours() throws {
        var configuration = AppConfiguration.initial
        configuration.timedReminders = [
            TimedReminderItem(text: "旧版提醒", hour: 10, minute: 20)
        ]
        let encoded = try JSONEncoder().encode(configuration)
        var legacyJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        var timedReminders = try XCTUnwrap(legacyJSON["timedReminders"] as? [[String: Any]])
        timedReminders[0].removeValue(forKey: "intervalHours")
        timedReminders[0].removeValue(forKey: "soundName")
        timedReminders[0].removeValue(forKey: "monthlyDays")
        timedReminders[0].removeValue(forKey: "autoCloseEnabled")
        legacyJSON["timedReminders"] = timedReminders
        defaults.set(try JSONSerialization.data(withJSONObject: legacyJSON), forKey: "test")

        let store = ConfigurationStore(defaults: defaults, storageKey: "test")

        XCTAssertEqual(
            store.configuration.timedReminders.first?.intervalHours,
            TimedReminderItem.defaultIntervalHours
        )
        XCTAssertNil(store.configuration.timedReminders.first?.soundName)
        XCTAssertNil(store.configuration.timedReminders.first?.specificDate)
        XCTAssertEqual(store.configuration.timedReminders.first?.monthlyDays, [.day(1)])
        XCTAssertFalse(store.configuration.timedReminders[0].autoCloseEnabled)
    }

    func testLegacyAutoCloseDefaultFollowsReminderFrequency() throws {
        var configuration = AppConfiguration.initial
        configuration.timedReminders = [
            TimedReminderItem(text: "小时提醒", frequency: .hourlyInterval, hour: 9, minute: 0),
            TimedReminderItem(text: "每日提醒", frequency: .daily, hour: 10, minute: 0),
        ]
        let encoded = try JSONEncoder().encode(configuration)
        var legacyJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        var timedReminders = try XCTUnwrap(legacyJSON["timedReminders"] as? [[String: Any]])
        for index in timedReminders.indices {
            timedReminders[index].removeValue(forKey: "autoCloseEnabled")
        }
        legacyJSON["timedReminders"] = timedReminders
        defaults.set(try JSONSerialization.data(withJSONObject: legacyJSON), forKey: "test")

        let store = ConfigurationStore(defaults: defaults, storageKey: "test")

        XCTAssertTrue(store.configuration.timedReminders[0].autoCloseEnabled)
        XCTAssertFalse(store.configuration.timedReminders[1].autoCloseEnabled)
    }

    func testSingleMonthlyDayConfigurationMigratesToMultipleSelection() throws {
        var configuration = AppConfiguration.initial
        configuration.timedReminders = [
            TimedReminderItem(text: "旧版月度提醒", hour: 10, minute: 20)
        ]
        let encoded = try JSONEncoder().encode(configuration)
        var legacyJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        var timedReminders = try XCTUnwrap(legacyJSON["timedReminders"] as? [[String: Any]])
        timedReminders[0].removeValue(forKey: "monthlyDays")
        timedReminders[0]["monthlyDay"] = ["rawValue": MonthlyReminderDay.lastDay.rawValue]
        legacyJSON["timedReminders"] = timedReminders
        defaults.set(try JSONSerialization.data(withJSONObject: legacyJSON), forKey: "test")

        let store = ConfigurationStore(defaults: defaults, storageKey: "test")

        XCTAssertEqual(store.configuration.timedReminders.first?.monthlyDays, [.lastDay])
    }

    func testRemovedFirstDayOptionMigratesToNumberedDayOne() throws {
        var configuration = AppConfiguration.initial
        configuration.timedReminders = [
            TimedReminderItem(
                text: "旧版月初提醒",
                frequency: .monthly,
                monthlyDays: [.firstDay],
                hour: 9,
                minute: 0
            )
        ]
        defaults.set(try JSONEncoder().encode(configuration), forKey: "test")

        let store = ConfigurationStore(defaults: defaults, storageKey: "test")

        XCTAssertEqual(store.configuration.timedReminders.first?.monthlyDays, [.day(1)])
    }

    func testTimedReminderValuesAreSanitized() {
        let reminder = TimedReminderItem(
            text: "边界检查",
            frequency: .selectedWeekdays,
            selectedWeekdays: [],
            monthlyDays: [],
            hour: 99,
            minute: -4,
            intervalHours: 99,
            soundName: "   "
        ).sanitized()

        XCTAssertEqual(reminder.hour, 23)
        XCTAssertEqual(reminder.minute, 0)
        XCTAssertEqual(reminder.intervalHours, 24)
        XCTAssertNil(reminder.soundName)
        XCTAssertEqual(reminder.selectedWeekdays, [.monday])
        XCTAssertEqual(reminder.monthlyDays, [.day(1)])
    }

    func testMonthlyReminderDayOptionsAndSanitization() {
        XCTAssertEqual(MonthlyReminderDay.allOptions.count, 32)
        XCTAssertEqual(Set(MonthlyReminderDay.allOptions).count, 32)
        XCTAssertTrue((1...31).allSatisfy { MonthlyReminderDay.allOptions.contains(.day($0)) })
        XCTAssertFalse(MonthlyReminderDay.allOptions.contains(.firstDay))
        XCTAssertTrue(MonthlyReminderDay.allOptions.contains(.lastDay))
        XCTAssertEqual(MonthlyReminderDay.firstDay.sanitized(), .day(1))
        XCTAssertEqual(MonthlyReminderDay(rawValue: 99).sanitized(), .day(1))
    }

    func testMonthlyFrequencyAppearsBeforeSelectedWeekdays() throws {
        let monthlyIndex = try XCTUnwrap(TimedReminderFrequency.allCases.firstIndex(of: .monthly))
        let weekdaysIndex = try XCTUnwrap(
            TimedReminderFrequency.allCases.firstIndex(of: .selectedWeekdays)
        )

        XCTAssertLessThan(monthlyIndex, weekdaysIndex)
    }

    func testSettingsMenuItemExplicitlyHidesImageWhenSupported() {
        let item = NSMenuItem(title: "打开设置…", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)

        MenuItemImageVisibilityCompatibility.hideImage(for: item)

        XCTAssertNil(item.image)
        let visibilitySetter = NSSelectorFromString("setPreferredImageVisibility:")
        if item.responds(to: visibilitySetter) {
            let visibility = item.value(forKey: "preferredImageVisibility") as? NSNumber
            XCTAssertEqual(visibility?.intValue, 2)
        }
    }

    func testTimedReminderDefaultsToNoSound() {
        let reminder = TimedReminderItem(text: "安静提醒", hour: 9, minute: 0)

        XCTAssertNil(reminder.soundName)
        XCTAssertNil(SystemSoundLibrary.sound(named: reminder.soundName))
    }

    func testExposedSystemSoundsHaveUniqueIdentifiersAndCanBeLoaded() {
        let sounds = SystemSoundLibrary.availableSounds

        XCTAssertFalse(sounds.isEmpty)
        XCTAssertEqual(Set(sounds.map(\.id)).count, sounds.count)
        XCTAssertTrue(sounds.allSatisfy { !$0.displayName.isEmpty })

        if Locale.preferredLanguages.first?.hasPrefix("zh") == true,
           let radial = sounds.first(where: { $0.id == "Radial-EncoreInfinitum" }) {
            XCTAssertEqual(radial.displayName, "射线")
        }

        for sound in sounds.prefix(3) {
            XCTAssertNotNil(SystemSoundLibrary.sound(named: sound.id))
        }
    }

    func testSnoozeDurationsUseRequestedMinuteOptions() {
        XCTAssertEqual(
            TimedReminderSnoozeDuration.allCases.map(\.rawValue),
            [5, 10, 20]
        )
    }

    func testSnoozeQueueDeliversAtRequestedTimeOnlyOnce() throws {
        var queue = TimedReminderSnoozeQueue()
        let calendar = utcGregorianCalendar()
        let now = try makeDate(2024, 1, 1, 9, 0, calendar: calendar)
        let reminder = TimedReminderItem(text: "稍后再做", hour: 9, minute: 0)

        let fireDate = queue.schedule(reminder, after: .tenMinutes, now: now)

        XCTAssertEqual(fireDate, now.addingTimeInterval(10 * 60))
        XCTAssertTrue(
            queue.remindersDue(through: now.addingTimeInterval(10 * 60 - 1)).isEmpty
        )
        XCTAssertEqual(
            queue.remindersDue(through: now.addingTimeInterval(10 * 60)),
            [reminder]
        )
        XCTAssertTrue(
            queue.remindersDue(through: now.addingTimeInterval(20 * 60)).isEmpty
        )
    }

    func testPopupConfirmsSelectedSnoozeDuration() {
        let model = TimedReminderPopupModel()
        var confirmedDuration: TimedReminderSnoozeDuration?
        model.snooze = { confirmedDuration = $0 }
        model.snoozeDuration = .twentyMinutes

        model.confirmSnooze()

        XCTAssertEqual(confirmedDuration, .twentyMinutes)
    }

    func testPopupPresentationTimeIsLocalizedWithoutYearOrSeconds() throws {
        let model = TimedReminderPopupModel()
        model.displayLanguage = .englishUS
        model.presentationDate = try makeDate(
            2026,
            9,
            10,
            14,
            7,
            calendar: utcGregorianCalendar()
        )

        let text = model.presentationTimeText(timeZone: try XCTUnwrap(TimeZone(secondsFromGMT: 0)))

        XCTAssertEqual(text, "Sep 10, 2:07 PM")
        XCTAssertFalse(text.contains("2026"))
    }

    func testTimedReminderAutoCloseDefaultsFollowFrequencyAndPreserveOverrides() {
        XCTAssertTrue(
            TimedReminderItem(
                text: "小时提醒",
                frequency: .hourlyInterval,
                hour: 9,
                minute: 0
            ).autoCloseEnabled
        )
        XCTAssertFalse(
            TimedReminderItem(
                text: "每日提醒",
                frequency: .daily,
                hour: 9,
                minute: 0
            ).autoCloseEnabled
        )

        var reminder = TimedReminderItem(text: "切换频率", hour: 9, minute: 0)
        reminder.updateFrequency(.hourlyInterval)
        XCTAssertTrue(reminder.autoCloseEnabled)

        reminder.autoCloseEnabled = false
        reminder.updateFrequency(.monthly)
        XCTAssertFalse(reminder.autoCloseEnabled)

        reminder.autoCloseEnabled = true
        reminder.updateFrequency(.selectedWeekdays)
        XCTAssertTrue(reminder.autoCloseEnabled)
    }

    func testNewTimedReminderDefaultsToCurrentWholeHour() throws {
        let calendar = utcGregorianCalendar()
        let store = ConfigurationStore(defaults: defaults, storageKey: "test")

        store.addTimedReminder(
            now: try makeDate(2024, 1, 1, 10, 25, calendar: calendar),
            calendar: calendar
        )

        XCTAssertEqual(store.configuration.timedReminders.last?.hour, 10)
        XCTAssertEqual(store.configuration.timedReminders.last?.minute, 0)
        XCTAssertEqual(store.configuration.timedReminders.last?.selectedWeekdays, [.monday])
        XCTAssertFalse(store.configuration.timedReminders.last?.autoCloseEnabled ?? true)
    }

    func testTimedReminderBindingRemainsReadableWhileDeletedRowIsDismantled() {
        let store = ConfigurationStore(defaults: defaults, storageKey: "test")
        let reminder = TimedReminderItem(text: "即将删除", hour: 9, minute: 0)
        store.configuration.timedReminders = [reminder]
        let settingsView = SettingsView(store: store, resetPosition: {})
        let textBinding = settingsView.timedReminderBinding(for: reminder, keyPath: \.text)
        let enabledBinding = settingsView.timedReminderBinding(for: reminder, keyPath: \.isEnabled)

        store.removeTimedReminder(id: reminder.id)

        XCTAssertEqual(textBinding.wrappedValue, "即将删除")
        XCTAssertTrue(enabledBinding.wrappedValue)

        textBinding.wrappedValue = "不应重新写入"
        enabledBinding.wrappedValue = false
        XCTAssertTrue(store.configuration.timedReminders.isEmpty)
    }

    func testHourlyIntervalReminderRepeatsFromDailyStartTime() throws {
        let calendar = utcGregorianCalendar()
        let reminder = TimedReminderItem(
            text: "活动一下",
            frequency: .hourlyInterval,
            hour: 9,
            minute: 15,
            intervalHours: 3
        )

        let beforeStart = TimedReminderSchedule.nextOccurrence(
            after: try makeDate(2024, 1, 1, 8, 0, calendar: calendar),
            for: reminder,
            calendar: calendar
        )
        let betweenIntervals = TimedReminderSchedule.nextOccurrence(
            after: try makeDate(2024, 1, 1, 10, 0, calendar: calendar),
            for: reminder,
            calendar: calendar
        )
        let afterLastInterval = TimedReminderSchedule.nextOccurrence(
            after: try makeDate(2024, 1, 1, 22, 0, calendar: calendar),
            for: reminder,
            calendar: calendar
        )

        XCTAssertEqual(beforeStart?.date, try makeDate(2024, 1, 1, 9, 15, calendar: calendar))
        XCTAssertEqual(betweenIntervals?.date, try makeDate(2024, 1, 1, 12, 15, calendar: calendar))
        XCTAssertEqual(afterLastInterval?.date, try makeDate(2024, 1, 2, 9, 15, calendar: calendar))
    }

    func testCannotRemoveLastSelectedWeekday() {
        let store = ConfigurationStore(defaults: defaults, storageKey: "test")
        let reminder = TimedReminderItem(
            text: "周一提醒",
            frequency: .selectedWeekdays,
            selectedWeekdays: [.monday],
            hour: 9,
            minute: 0
        )
        store.configuration.timedReminders = [reminder]

        store.toggleTimedReminderWeekday(id: reminder.id, weekday: .monday)

        XCTAssertEqual(store.configuration.timedReminders[0].selectedWeekdays, [.monday])
    }

    func testCannotRemoveLastSelectedMonthlyDay() {
        let store = ConfigurationStore(defaults: defaults, storageKey: "test")
        let reminder = TimedReminderItem(
            text: "每月一号提醒",
            frequency: .monthly,
            monthlyDays: [.day(1)],
            hour: 9,
            minute: 0
        )
        store.configuration.timedReminders = [reminder]

        store.toggleTimedReminderMonthlyDay(id: reminder.id, day: .day(1))

        XCTAssertEqual(store.configuration.timedReminders[0].monthlyDays, [.day(1)])
    }

    func testDailyTimedReminderFindsSameDayAndNextDayOccurrences() throws {
        let calendar = utcGregorianCalendar()
        let reminder = TimedReminderItem(text: "喝水", hour: 9, minute: 30)
        let morning = try makeDate(2024, 1, 1, 8, 0, calendar: calendar)
        let afternoon = try makeDate(2024, 1, 1, 10, 0, calendar: calendar)

        let sameDay = TimedReminderSchedule.nextOccurrence(after: morning, for: reminder, calendar: calendar)
        let nextDay = TimedReminderSchedule.nextOccurrence(after: afternoon, for: reminder, calendar: calendar)

        XCTAssertEqual(sameDay?.date, try makeDate(2024, 1, 1, 9, 30, calendar: calendar))
        XCTAssertEqual(nextDay?.date, try makeDate(2024, 1, 2, 9, 30, calendar: calendar))
    }

    func testWeekdayTimedReminderFindsNextSelectedDay() throws {
        let calendar = utcGregorianCalendar()
        let reminder = TimedReminderItem(
            text: "复盘",
            frequency: .selectedWeekdays,
            selectedWeekdays: [.wednesday, .friday],
            hour: 18,
            minute: 15
        )
        let monday = try makeDate(2024, 1, 1, 20, 0, calendar: calendar)

        let occurrence = TimedReminderSchedule.nextOccurrence(after: monday, for: reminder, calendar: calendar)

        XCTAssertEqual(occurrence?.date, try makeDate(2024, 1, 3, 18, 15, calendar: calendar))
    }

    func testMonthlyNumberedDaySkipsMonthsWithoutThatDate() throws {
        let calendar = utcGregorianCalendar()
        let reminder = TimedReminderItem(
            text: "月末报表",
            frequency: .monthly,
            monthlyDays: [.day(31)],
            hour: 9,
            minute: 30
        )

        let occurrence = TimedReminderSchedule.nextOccurrence(
            after: try makeDate(2024, 1, 31, 10, 0, calendar: calendar),
            for: reminder,
            calendar: calendar
        )

        XCTAssertEqual(occurrence?.date, try makeDate(2024, 3, 31, 9, 30, calendar: calendar))
    }

    func testMonthlyFirstAndLastDatesFollowCalendarMonth() throws {
        let calendar = utcGregorianCalendar()
        let firstDateReminder = TimedReminderItem(
            text: "月初计划",
            frequency: .monthly,
            monthlyDays: [.day(1)],
            hour: 8,
            minute: 0
        )
        let lastDayReminder = TimedReminderItem(
            text: "月末复盘",
            frequency: .monthly,
            monthlyDays: [.lastDay],
            hour: 18,
            minute: 45
        )

        let firstDateOccurrence = TimedReminderSchedule.nextOccurrence(
            after: try makeDate(2024, 1, 15, 12, 0, calendar: calendar),
            for: firstDateReminder,
            calendar: calendar
        )
        let lastDayOccurrence = TimedReminderSchedule.nextOccurrence(
            after: try makeDate(2024, 2, 1, 0, 0, calendar: calendar),
            for: lastDayReminder,
            calendar: calendar
        )

        XCTAssertEqual(firstDateOccurrence?.date, try makeDate(2024, 2, 1, 8, 0, calendar: calendar))
        XCTAssertEqual(lastDayOccurrence?.date, try makeDate(2024, 2, 29, 18, 45, calendar: calendar))
    }

    func testMonthlyReminderUsesNextSelectedDay() throws {
        let calendar = utcGregorianCalendar()
        let reminder = TimedReminderItem(
            text: "月度节点",
            frequency: .monthly,
            monthlyDays: [.day(5), .day(20)],
            hour: 9,
            minute: 30
        )

        let sameMonth = TimedReminderSchedule.nextOccurrence(
            after: try makeDate(2024, 1, 6, 10, 0, calendar: calendar),
            for: reminder,
            calendar: calendar
        )
        let nextMonth = TimedReminderSchedule.nextOccurrence(
            after: try makeDate(2024, 1, 20, 10, 0, calendar: calendar),
            for: reminder,
            calendar: calendar
        )

        XCTAssertEqual(sameMonth?.date, try makeDate(2024, 1, 20, 9, 30, calendar: calendar))
        XCTAssertEqual(nextMonth?.date, try makeDate(2024, 2, 5, 9, 30, calendar: calendar))
    }

    func testSpecificDateTimedReminderOnlyOccursOnce() throws {
        let calendar = utcGregorianCalendar()
        let targetDate = try makeDate(2024, 1, 3, 18, 15, calendar: calendar)
        let reminder = TimedReminderItem(
            text: "提交材料",
            frequency: .specificDate,
            hour: 18,
            minute: 15,
            specificDate: targetDate
        )

        let upcoming = TimedReminderSchedule.nextOccurrence(
            after: try makeDate(2024, 1, 3, 18, 14, calendar: calendar),
            for: reminder,
            calendar: calendar
        )
        let expired = TimedReminderSchedule.nextOccurrence(
            after: targetDate,
            for: reminder,
            calendar: calendar
        )

        XCTAssertEqual(upcoming?.date, targetDate)
        XCTAssertNil(expired)
    }

    func testSpecificDateTimedReminderWithoutDateHasNoOccurrence() throws {
        let calendar = utcGregorianCalendar()
        let reminder = TimedReminderItem(
            text: "尚未选择日期",
            frequency: .specificDate,
            hour: 9,
            minute: 0
        )

        let occurrence = TimedReminderSchedule.nextOccurrence(
            after: try makeDate(2024, 1, 1, 8, 0, calendar: calendar),
            for: reminder,
            calendar: calendar
        )

        XCTAssertNil(occurrence)
    }

    func testDisabledTimedReminderHasNoOccurrence() throws {
        let calendar = utcGregorianCalendar()
        let reminder = TimedReminderItem(text: "暂停", isEnabled: false, hour: 9, minute: 0)

        let occurrence = TimedReminderSchedule.nextOccurrence(
            after: try makeDate(2024, 1, 1, 8, 0, calendar: calendar),
            for: reminder,
            calendar: calendar
        )

        XCTAssertNil(occurrence)
    }

    func testOccurrencesIncludeReminderWhenIntervalCrossesItsMinute() throws {
        let calendar = utcGregorianCalendar()
        let reminder = TimedReminderItem(text: "准时触发", hour: 9, minute: 34)
        let start = try makeDate(2024, 1, 1, 9, 33, calendar: calendar).addingTimeInterval(59)
        let end = try makeDate(2024, 1, 1, 9, 34, calendar: calendar).addingTimeInterval(1)

        let occurrences = TimedReminderSchedule.occurrences(
            after: start,
            through: end,
            reminders: [reminder],
            calendar: calendar
        )

        XCTAssertEqual(occurrences.map(\.reminderID), [reminder.id])
        XCTAssertEqual(occurrences.first?.date, try makeDate(2024, 1, 1, 9, 34, calendar: calendar))
    }

    func testSchedulerDeliversReminderAddedDuringCurrentMinuteOnlyOnce() {
        let store = ConfigurationStore(defaults: defaults, storageKey: "test")
        store.configuration.timedReminders = []
        var deliveredIDs: [TimedReminderItem.ID] = []
        let scheduler = TimedReminderScheduler(store: store) { reminders in
            deliveredIDs.append(contentsOf: reminders.map(\.id))
        }
        scheduler.start()

        let now = Date()
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: now)
        let reminder = TimedReminderItem(
            text: "当前分钟提醒",
            hour: components.hour ?? 0,
            minute: components.minute ?? 0
        )
        store.configuration.timedReminders = [reminder]
        store.configuration.timedReminders[0].text = "修改后不应重复触发"

        XCTAssertEqual(deliveredIDs, [reminder.id])
    }

    func testSchedulerDoesNotRedeliverCurrentOccurrenceAfterRestart() {
        let store = ConfigurationStore(defaults: defaults, storageKey: "test")
        let now = Date()
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: now)
        let reminder = TimedReminderItem(
            text: "重启后不应重复触发",
            hour: components.hour ?? 0,
            minute: components.minute ?? 0
        )
        store.configuration.timedReminders = [reminder]
        var deliveredIDs: [TimedReminderItem.ID] = []

        let firstScheduler = TimedReminderScheduler(
            store: store,
            defaults: defaults,
            deliveryHistoryStorageKey: "delivery-history"
        ) { reminders in
            deliveredIDs.append(contentsOf: reminders.map(\.id))
        }
        firstScheduler.start()

        let restartedScheduler = TimedReminderScheduler(
            store: store,
            defaults: defaults,
            deliveryHistoryStorageKey: "delivery-history"
        ) { reminders in
            deliveredIDs.append(contentsOf: reminders.map(\.id))
        }
        restartedScheduler.start()

        XCTAssertEqual(deliveredIDs, [reminder.id])
    }

    func testItemVisibilityCanBeToggledAndFiltersDesktopItems() {
        let store = ConfigurationStore(defaults: defaults, storageKey: "test")
        let hiddenID = store.configuration.items[1].id

        store.toggleItemVisibility(id: hiddenID)

        XCTAssertFalse(store.configuration.items[1].isVisible)
        XCTAssertEqual(store.configuration.visibleItems.count, 2)
        XCTAssertFalse(store.configuration.visibleItems.contains { $0.id == hiddenID })
    }

    func testFontSizeIsClampedToSupportedRange() {
        var configuration = AppConfiguration.initial

        configuration.reminderFontSize = 2
        XCTAssertEqual(configuration.sanitized().reminderFontSize, 12)

        configuration.reminderFontSize = 200
        XCTAssertEqual(configuration.sanitized().reminderFontSize, 32)
    }

    func testReminderWidthIsClampedToSupportedRange() {
        var configuration = AppConfiguration.initial

        configuration.reminderWidth = 100
        XCTAssertEqual(configuration.sanitized().reminderWidth, 240)

        configuration.reminderWidth = 800
        XCTAssertEqual(configuration.sanitized().reminderWidth, 560)
    }

    func testTimedReminderBackgroundImageStoreKeepsAnIndependentCopy() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimedReminderBackgroundTests-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = temporaryDirectory.appendingPathComponent("source.png")
        let managedDirectory = temporaryDirectory.appendingPathComponent("managed", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        try makeTestPNGData().write(to: sourceURL, options: .atomic)

        let imageStore = TimedReminderBackgroundImageStore(directoryURL: managedDirectory)
        let imageName = try imageStore.importImage(from: sourceURL)
        try FileManager.default.removeItem(at: sourceURL)

        XCTAssertNotNil(imageStore.image(named: imageName))

        try imageStore.removeImage(named: imageName)
        XCTAssertNil(imageStore.image(named: imageName))
    }

    func testTimedReminderBackgroundImageNameRejectsPaths() {
        var configuration = AppConfiguration.initial
        configuration.timedReminders = [
            TimedReminderItem(
                text: "边界检查",
                hour: 9,
                minute: 0,
                backgroundImageName: "../outside.png"
            )
        ]

        XCTAssertNil(configuration.sanitized().timedReminders.first?.backgroundImageName)
    }

    func testBackgroundGalleryListsBuiltInsBeforeUploadsAndProtectsBuiltIns() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackgroundGalleryTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let builtIns = root.appendingPathComponent("AlarmBg", isDirectory: true)
        try FileManager.default.createDirectory(at: builtIns, withIntermediateDirectories: true)
        let imageData = try makeTestPNGData()
        try imageData.write(to: builtIns.appendingPathComponent("02.png"))
        try imageData.write(to: builtIns.appendingPathComponent("01.png"))
        try Data("not an image".utf8).write(to: builtIns.appendingPathComponent("notes.txt"))
        let imageStore = TimedReminderBackgroundImageStore(
            directoryURL: root.appendingPathComponent("uploads"),
            builtInDirectoryURL: builtIns
        )
        let firstUpload = try imageStore.importImage(from: builtIns.appendingPathComponent("01.png"))
        let secondUpload = try imageStore.importImage(from: builtIns.appendingPathComponent("02.png"))
        let entries = try imageStore.entries()
        XCTAssertEqual(entries.prefix(2).map(\.id), ["builtin:01.png", "builtin:02.png"])
        XCTAssertEqual(entries.prefix(2).map(\.displayName), ["系统内置 #1", "系统内置 #2"])
        let uploadEntries = entries.filter(\.isUserImage)
        XCTAssertEqual(uploadEntries.count, 2)
        XCTAssertEqual(uploadEntries.map(\.id), [firstUpload, secondUpload])
        XCTAssertEqual(uploadEntries.map(\.displayName), ["自定义图片 #1", "自定义图片 #2"])
        XCTAssertNotNil(imageStore.image(named: "builtin:01.png"))
        XCTAssertNil(imageStore.image(named: "builtin:../01.png"))
        try imageStore.removeImage(named: "builtin:01.png")
        XCTAssertNotNil(imageStore.image(named: "builtin:01.png"))
        try imageStore.removeImage(named: firstUpload)
        XCTAssertNil(imageStore.image(named: firstUpload))
        XCTAssertNotNil(imageStore.image(named: secondUpload))

        let configurationStore = ConfigurationStore(defaults: defaults, storageKey: "gallery")
        configurationStore.configuration.timedReminders = [
            TimedReminderItem(
                text: "背景测试",
                hour: 9,
                minute: 0,
                backgroundImageName: "builtin:02.png"
            )
        ]
        let restored = ConfigurationStore(defaults: defaults, storageKey: "gallery")
        XCTAssertEqual(restored.configuration.timedReminders.first?.backgroundImageName, "builtin:02.png")
    }

    func testLegacyGlobalBackgroundMigratesToEveryTimedReminder() throws {
        var configuration = AppConfiguration.initial
        configuration.timedReminders = [
            TimedReminderItem(text: "提醒一", hour: 9, minute: 0),
            TimedReminderItem(text: "提醒二", hour: 10, minute: 0),
        ]
        let encoded = try JSONEncoder().encode(configuration)
        var legacyJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        legacyJSON["timedReminderBackgroundImageName"] = "builtin:02.png"
        defaults.set(try JSONSerialization.data(withJSONObject: legacyJSON), forKey: "legacy-gallery")

        let restored = ConfigurationStore(defaults: defaults, storageKey: "legacy-gallery")

        XCTAssertEqual(
            restored.configuration.timedReminders.map(\.backgroundImageName),
            ["builtin:02.png", "builtin:02.png"]
        )
    }

    func testBackgroundUsageChecksAllTimedReminders() {
        let store = ConfigurationStore(defaults: defaults, storageKey: "usage")
        store.configuration.timedReminders = [
            TimedReminderItem(
                text: "使用图片",
                hour: 9,
                minute: 0,
                backgroundImageName: "upload.png"
            ),
            TimedReminderItem(text: "不使用图片", hour: 10, minute: 0),
        ]

        XCTAssertEqual(
            store.timedReminders(usingBackgroundImageNamed: "upload.png").map(\.text),
            ["使用图片"]
        )
        XCTAssertTrue(store.timedReminders(usingBackgroundImageNamed: "unused.png").isEmpty)
    }

    func testSelectingResidentReminderPositionClearsManualPosition() {
        let store = ConfigurationStore(defaults: defaults, storageKey: "test")
        store.configuration.savedWindowOrigin = SavedWindowOrigin(x: 100, y: 200)

        store.selectResidentReminderPosition(.bottomCenter)

        XCTAssertEqual(store.configuration.residentReminderPosition, .bottomCenter)
        XCTAssertNil(store.configuration.savedWindowOrigin)
    }

    func testResidentReminderPositionOriginsCoverAllScreenAnchors() {
        let screen = CGRect(x: 100, y: 200, width: 1_000, height: 800)
        let windowSize = CGSize(width: 300, height: 200)
        let margin: CGFloat = 28

        XCTAssertEqual(
            ResidentReminderPosition.topRight.windowOrigin(
                in: screen,
                windowSize: windowSize,
                margin: margin
            ),
            CGPoint(x: 772, y: 772)
        )
        XCTAssertEqual(
            ResidentReminderPosition.centerRight.windowOrigin(
                in: screen,
                windowSize: windowSize,
                margin: margin
            ),
            CGPoint(x: 772, y: 500)
        )
        XCTAssertEqual(
            ResidentReminderPosition.bottomRight.windowOrigin(
                in: screen,
                windowSize: windowSize,
                margin: margin
            ),
            CGPoint(x: 772, y: 228)
        )
        XCTAssertEqual(
            ResidentReminderPosition.topLeft.windowOrigin(
                in: screen,
                windowSize: windowSize,
                margin: margin
            ),
            CGPoint(x: 128, y: 772)
        )
        XCTAssertEqual(
            ResidentReminderPosition.centerLeft.windowOrigin(
                in: screen,
                windowSize: windowSize,
                margin: margin
            ),
            CGPoint(x: 128, y: 500)
        )
        XCTAssertEqual(
            ResidentReminderPosition.bottomLeft.windowOrigin(
                in: screen,
                windowSize: windowSize,
                margin: margin
            ),
            CGPoint(x: 128, y: 228)
        )
        XCTAssertEqual(
            ResidentReminderPosition.topCenter.windowOrigin(
                in: screen,
                windowSize: windowSize,
                margin: margin
            ),
            CGPoint(x: 450, y: 772)
        )
        XCTAssertEqual(
            ResidentReminderPosition.bottomCenter.windowOrigin(
                in: screen,
                windowSize: windowSize,
                margin: margin
            ),
            CGPoint(x: 450, y: 228)
        )
    }

    func testCardLayoutUsesConfiguredReminderWidth() {
        let narrow = ReminderCardLayout(fontSize: 17, panelWidth: 240)
        let wide = ReminderCardLayout(fontSize: 17, panelWidth: 560)

        XCTAssertEqual(narrow.panelWidth, 240)
        XCTAssertEqual(wide.panelWidth, 560)
        XCTAssertGreaterThan(wide.availableTextWidth, narrow.availableTextWidth)
    }

    func testCardLayoutScalesWithReminderFontSize() {
        let small = ReminderCardLayout(fontSize: 12)
        let standard = ReminderCardLayout(fontSize: AppConfiguration.defaultReminderFontSize)
        let large = ReminderCardLayout(fontSize: 32)

        XCTAssertEqual(standard.scale, 1)
        XCTAssertEqual(standard.numberDiameter, 18)
        XCTAssertEqual(standard.contentSpacing, 9)
        XCTAssertEqual(standard.horizontalPadding, 16)
        XCTAssertEqual(standard.verticalPadding, 15)

        XCTAssertLessThan(small.numberDiameter, standard.numberDiameter)
        XCTAssertLessThan(small.horizontalPadding, standard.horizontalPadding)
        XCTAssertGreaterThan(large.numberDiameter, standard.numberDiameter)
        XCTAssertGreaterThan(large.horizontalPadding, standard.horizontalPadding)
        XCTAssertLessThan(large.availableTextWidth, standard.availableTextWidth)
    }

    func testCanDeleteLastReminder() {
        let store = ConfigurationStore(defaults: defaults, storageKey: "test")
        store.configuration.items = [ReminderItem(text: "保留我")]

        store.removeItem(id: store.configuration.items[0].id)

        XCTAssertTrue(store.configuration.items.isEmpty)
    }

    func testMoveItemRejectsOutOfBoundsAndMovesValidItem() {
        let store = ConfigurationStore(defaults: defaults, storageKey: "test")
        let originalFirstID = store.configuration.items[0].id

        store.moveItem(id: originalFirstID, offset: -1)
        XCTAssertEqual(store.configuration.items[0].id, originalFirstID)

        store.moveItem(id: originalFirstID, offset: 1)
        XCTAssertEqual(store.configuration.items[1].id, originalFirstID)
    }

    func testPersistedEmptyItemListRemainsEmpty() throws {
        var configuration = AppConfiguration.initial
        configuration.items = []
        defaults.set(try JSONEncoder().encode(configuration), forKey: "test")

        let store = ConfigurationStore(defaults: defaults, storageKey: "test")

        XCTAssertTrue(store.configuration.items.isEmpty)
    }

    func testDragAreaExplicitlyAllowsWindowMovementOnFirstClick() {
        let dragArea = WindowDragAreaView()

        XCTAssertTrue(dragArea.mouseDownCanMoveWindow)
        XCTAssertTrue(dragArea.acceptsFirstMouse(for: nil))
    }

    func testEntireOverlayPrioritizesDragAreaForHitTesting() {
        let boardSize = CGSize(width: ReminderCardLayout.panelWidth, height: 320)
        let contentView = OverlayContentView(configuration: .initial, size: boardSize)
        contentView.layoutSubtreeIfNeeded()

        XCTAssertEqual(contentView.dragArea.frame, contentView.bounds)

        let points = [
            CGPoint(x: contentView.bounds.midX, y: contentView.bounds.maxY - 4),
            CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY),
            CGPoint(x: contentView.bounds.midX, y: contentView.bounds.minY + 4),
        ]
        for point in points {
            XCTAssertTrue(contentView.hitTest(point) === contentView.dragArea)
        }
    }

    private func utcGregorianCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeTestPNGData() throws -> Data {
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.systemOrange.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 4, height: 4)).fill()
        image.unlockFocus()

        let tiffData = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiffData))
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        calendar: Calendar
    ) throws -> Date {
        try XCTUnwrap(
            calendar.date(
                from: DateComponents(
                    year: year,
                    month: month,
                    day: day,
                    hour: hour,
                    minute: minute,
                    second: 0
                )
            )
        )
    }
}
