import AppKit
import SwiftUI

struct ReminderItem: Codable, Equatable, Identifiable {
    var id: UUID
    var text: String
    var isVisible: Bool

    init(id: UUID = UUID(), text: String, isVisible: Bool = true) {
        self.id = id
        self.text = text
        self.isVisible = isVisible
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case isVisible
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
    }
}

enum TimedReminderFrequency: String, Codable, CaseIterable, Hashable {
    case hourlyInterval
    case daily
    case monthly
    case selectedWeekdays
    case specificDate

    func title(language: AppLanguage) -> String {
        language.localized(titleKey)
    }

    private var titleKey: String {
        switch self {
        case .hourlyInterval: "每隔几小时"
        case .daily: "每天"
        case .selectedWeekdays: "指定星期"
        case .monthly: "每月"
        case .specificDate: "指定日期"
        }
    }

    var defaultAutoCloseEnabled: Bool {
        self == .hourlyInterval
    }
}

enum ReminderWeekday: Int, Codable, CaseIterable, Hashable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1

    func shortTitle(language: AppLanguage) -> String {
        let titles: [ReminderWeekday: [AppLanguage: String]] = [
            .monday: [.simplifiedChinese: "一", .traditionalChinese: "一", .englishUS: "M"],
            .tuesday: [.simplifiedChinese: "二", .traditionalChinese: "二", .englishUS: "T"],
            .wednesday: [.simplifiedChinese: "三", .traditionalChinese: "三", .englishUS: "W"],
            .thursday: [.simplifiedChinese: "四", .traditionalChinese: "四", .englishUS: "T"],
            .friday: [.simplifiedChinese: "五", .traditionalChinese: "五", .englishUS: "F"],
            .saturday: [.simplifiedChinese: "六", .traditionalChinese: "六", .englishUS: "S"],
            .sunday: [.simplifiedChinese: "日", .traditionalChinese: "日", .englishUS: "S"],
        ]
        return titles[self]?[language.resolved] ?? "?"
    }

    func fullTitle(language: AppLanguage) -> String {
        let titles: [ReminderWeekday: [AppLanguage: String]] = [
            .monday: [.simplifiedChinese: "周一", .traditionalChinese: "週一", .englishUS: "Monday"],
            .tuesday: [.simplifiedChinese: "周二", .traditionalChinese: "週二", .englishUS: "Tuesday"],
            .wednesday: [.simplifiedChinese: "周三", .traditionalChinese: "週三", .englishUS: "Wednesday"],
            .thursday: [.simplifiedChinese: "周四", .traditionalChinese: "週四", .englishUS: "Thursday"],
            .friday: [.simplifiedChinese: "周五", .traditionalChinese: "週五", .englishUS: "Friday"],
            .saturday: [.simplifiedChinese: "周六", .traditionalChinese: "週六", .englishUS: "Saturday"],
            .sunday: [.simplifiedChinese: "周日", .traditionalChinese: "週日", .englishUS: "Sunday"],
        ]
        return titles[self]?[language.resolved] ?? "?"
    }

    var shortTitle: String {
        switch self {
        case .monday: "一"
        case .tuesday: "二"
        case .wednesday: "三"
        case .thursday: "四"
        case .friday: "五"
        case .saturday: "六"
        case .sunday: "日"
        }
    }
}

struct MonthlyReminderDay: Codable, Equatable, Hashable, Identifiable {
    static let numberedDayRange = 1...31
    // Retained only to migrate configurations saved before "第一天" was removed.
    static let firstDay = MonthlyReminderDay(rawValue: 0)
    static let lastDay = MonthlyReminderDay(rawValue: 32)
    static let allOptions = numberedDayRange.map(day) + [lastDay]

    let rawValue: Int

    var id: Int { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case Self.firstDay: language.localized("第一天")
        case Self.lastDay: language.localized("最后一天")
        default:
            language.resolved == .englishUS ? String(rawValue) : "\(rawValue) \(language.localized("号"))"
        }
    }

    var title: String { title(language: .simplifiedChinese) }

    static func day(_ day: Int) -> MonthlyReminderDay {
        MonthlyReminderDay(rawValue: day)
    }

    func resolvedDay(in range: Range<Int>) -> Int? {
        switch self {
        case Self.firstDay:
            range.first
        case Self.lastDay:
            range.last
        default:
            range.contains(rawValue) ? rawValue : nil
        }
    }

    func sanitized() -> MonthlyReminderDay {
        if self == Self.firstDay {
            return .day(1)
        }
        return Self.allOptions.contains(self) ? self : .day(1)
    }
}

struct TimedReminderItem: Codable, Equatable, Identifiable {
    static let defaultIntervalHours = 2
    static let intervalHoursRange = 1...24

    var id: UUID
    var text: String
    var isEnabled: Bool
    var frequency: TimedReminderFrequency
    var selectedWeekdays: Set<ReminderWeekday>
    var monthlyDays: Set<MonthlyReminderDay>
    var hour: Int
    var minute: Int
    var specificDate: Date?
    var intervalHours: Int
    var soundName: String?
    var autoCloseEnabled: Bool
    var backgroundImageName: String?

    init(
        id: UUID = UUID(),
        text: String,
        isEnabled: Bool = true,
        frequency: TimedReminderFrequency = .daily,
        selectedWeekdays: Set<ReminderWeekday> = [.monday],
        monthlyDays: Set<MonthlyReminderDay> = [.day(1)],
        hour: Int,
        minute: Int,
        specificDate: Date? = nil,
        intervalHours: Int = Self.defaultIntervalHours,
        soundName: String? = nil,
        autoCloseEnabled: Bool? = nil,
        backgroundImageName: String? = nil
    ) {
        self.id = id
        self.text = text
        self.isEnabled = isEnabled
        self.frequency = frequency
        self.selectedWeekdays = selectedWeekdays
        self.monthlyDays = monthlyDays
        self.hour = hour
        self.minute = minute
        self.specificDate = specificDate
        self.intervalHours = intervalHours
        self.soundName = soundName
        self.autoCloseEnabled = autoCloseEnabled ?? frequency.defaultAutoCloseEnabled
        self.backgroundImageName = backgroundImageName
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case isEnabled
        case frequency
        case selectedWeekdays
        case monthlyDays
        case hour
        case minute
        case specificDate
        case intervalHours
        case soundName
        case autoCloseEnabled
        case backgroundImageName
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case monthlyDay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        frequency = try container.decodeIfPresent(TimedReminderFrequency.self, forKey: .frequency) ?? .daily
        selectedWeekdays = try container.decodeIfPresent(Set<ReminderWeekday>.self, forKey: .selectedWeekdays)
            ?? [.monday]
        if let decodedMonthlyDays = try container.decodeIfPresent(
            Set<MonthlyReminderDay>.self,
            forKey: .monthlyDays
        ) {
            monthlyDays = decodedMonthlyDays
        } else if let legacyMonthlyDay = try decoder.container(keyedBy: LegacyCodingKeys.self).decodeIfPresent(
            MonthlyReminderDay.self,
            forKey: .monthlyDay
        ) {
            monthlyDays = [legacyMonthlyDay]
        } else {
            monthlyDays = [.day(1)]
        }
        hour = try container.decodeIfPresent(Int.self, forKey: .hour) ?? 9
        minute = try container.decodeIfPresent(Int.self, forKey: .minute) ?? 0
        specificDate = try container.decodeIfPresent(Date.self, forKey: .specificDate)
        intervalHours = try container.decodeIfPresent(Int.self, forKey: .intervalHours)
            ?? Self.defaultIntervalHours
        soundName = try container.decodeIfPresent(String.self, forKey: .soundName)
        autoCloseEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoCloseEnabled)
            ?? frequency.defaultAutoCloseEnabled
        backgroundImageName = try container.decodeIfPresent(String.self, forKey: .backgroundImageName)
    }

    mutating func updateFrequency(_ newFrequency: TimedReminderFrequency) {
        let usesCurrentFrequencyDefault = autoCloseEnabled == frequency.defaultAutoCloseEnabled
        frequency = newFrequency
        if usesCurrentFrequencyDefault {
            autoCloseEnabled = newFrequency.defaultAutoCloseEnabled
        }
    }

    func sanitized() -> TimedReminderItem {
        var copy = self
        copy.hour = copy.hour.clamped(to: 0...23)
        copy.minute = copy.minute.clamped(to: 0...59)
        copy.monthlyDays = Set(copy.monthlyDays.map { $0.sanitized() })
        if copy.monthlyDays.isEmpty {
            copy.monthlyDays = [.day(1)]
        }
        copy.intervalHours = copy.intervalHours.clamped(to: Self.intervalHoursRange)
        copy.soundName = copy.soundName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if copy.soundName?.isEmpty == true {
            copy.soundName = nil
        }
        copy.backgroundImageName = TimedReminderBackgroundImageReference.sanitized(
            copy.backgroundImageName
        )
        if copy.selectedWeekdays.isEmpty {
            copy.selectedWeekdays = [.monday]
        }
        return copy
    }
}

struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(_ color: Color) {
        let converted = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        self.init(
            red: Double(converted.redComponent),
            green: Double(converted.greenComponent),
            blue: Double(converted.blueComponent),
            alpha: Double(converted.alphaComponent)
        )
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

struct SavedWindowOrigin: Codable, Equatable {
    var x: Double
    var y: Double

    var point: CGPoint { CGPoint(x: x, y: y) }
}

enum ResidentReminderPosition: String, Codable, CaseIterable, Hashable, Identifiable {
    case topRight
    case centerRight
    case bottomRight
    case topLeft
    case centerLeft
    case bottomLeft
    case topCenter
    case bottomCenter

    var id: Self { self }

    func title(language: AppLanguage) -> String {
        language.localized(titleKey)
    }

    private var titleKey: String {
        switch self {
        case .topRight: "右上角"
        case .centerRight: "右侧中间"
        case .bottomRight: "右下角"
        case .topLeft: "左上角"
        case .centerLeft: "左侧中间"
        case .bottomLeft: "左下角"
        case .topCenter: "顶部居中"
        case .bottomCenter: "底部居中"
        }
    }

    func windowOrigin(
        in visibleFrame: CGRect,
        windowSize: CGSize,
        margin: CGFloat
    ) -> CGPoint {
        let leftX = visibleFrame.minX + margin
        let centerX = visibleFrame.midX - windowSize.width / 2
        let rightX = visibleFrame.maxX - windowSize.width - margin
        let bottomY = visibleFrame.minY + margin
        let centerY = visibleFrame.midY - windowSize.height / 2
        let topY = visibleFrame.maxY - windowSize.height - margin

        switch self {
        case .topRight: return CGPoint(x: rightX, y: topY)
        case .centerRight: return CGPoint(x: rightX, y: centerY)
        case .bottomRight: return CGPoint(x: rightX, y: bottomY)
        case .topLeft: return CGPoint(x: leftX, y: topY)
        case .centerLeft: return CGPoint(x: leftX, y: centerY)
        case .bottomLeft: return CGPoint(x: leftX, y: bottomY)
        case .topCenter: return CGPoint(x: centerX, y: topY)
        case .bottomCenter: return CGPoint(x: centerX, y: bottomY)
        }
    }
}

struct AppConfiguration: Codable, Equatable {
    static let defaultReminderFontSize = 17.0
    static let reminderFontSizeRange = 12.0...32.0
    static let defaultReminderWidth = 390.0
    static let reminderWidthRange = 240.0...560.0

    var items: [ReminderItem]
    var timedReminders: [TimedReminderItem]
    var backgroundColor: CodableColor
    var textColor: CodableColor
    var reminderFontSize: Double
    var reminderWidth: Double
    var isAlwaysOnTop: Bool
    var isOverlayVisible: Bool
    var residentReminderPosition: ResidentReminderPosition
    var savedWindowOrigin: SavedWindowOrigin?
    var displayLanguage: AppLanguage

    var visibleItems: [ReminderItem] {
        items.filter(\.isVisible)
    }

    static var initial: AppConfiguration {
        let language = AppLanguage.system
        return AppConfiguration(
            items: [
                ReminderItem(text: language.localized("先停一下：现在最重要的事情是什么？")),
                ReminderItem(text: language.localized("一次只做一件事，完成后再切换。")),
                ReminderItem(text: language.localized("坐直、放松肩膀，喝一口水。"))
            ],
            timedReminders: [],
            backgroundColor: CodableColor(red: 0.98, green: 0.82, blue: 0.32),
            textColor: CodableColor(red: 0.16, green: 0.12, blue: 0.06),
            reminderFontSize: defaultReminderFontSize,
            reminderWidth: defaultReminderWidth,
            isAlwaysOnTop: true,
            isOverlayVisible: true,
            residentReminderPosition: .topRight,
            savedWindowOrigin: nil,
            displayLanguage: .system
        )
    }

    func sanitized() -> AppConfiguration {
        var copy = self
        copy.timedReminders = copy.timedReminders.map { $0.sanitized() }
        copy.backgroundColor = copy.backgroundColor.clamped()
        copy.textColor = copy.textColor.clamped()
        copy.reminderFontSize = copy.reminderFontSize.clamped(to: Self.reminderFontSizeRange)
        copy.reminderWidth = copy.reminderWidth.clamped(to: Self.reminderWidthRange)
        return copy
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case timedReminders
        case backgroundColor
        case textColor
        case reminderFontSize
        case reminderWidth
        case isAlwaysOnTop
        case isOverlayVisible
        case residentReminderPosition
        case savedWindowOrigin
        case displayLanguage
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case timedReminderBackgroundImageName
    }

    init(
        items: [ReminderItem],
        timedReminders: [TimedReminderItem],
        backgroundColor: CodableColor,
        textColor: CodableColor,
        reminderFontSize: Double,
        reminderWidth: Double,
        isAlwaysOnTop: Bool,
        isOverlayVisible: Bool,
        residentReminderPosition: ResidentReminderPosition,
        savedWindowOrigin: SavedWindowOrigin?,
        displayLanguage: AppLanguage = .system
    ) {
        self.items = items
        self.timedReminders = timedReminders
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.reminderFontSize = reminderFontSize
        self.reminderWidth = reminderWidth
        self.isAlwaysOnTop = isAlwaysOnTop
        self.isOverlayVisible = isOverlayVisible
        self.residentReminderPosition = residentReminderPosition
        self.savedWindowOrigin = savedWindowOrigin
        self.displayLanguage = displayLanguage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([ReminderItem].self, forKey: .items)
        timedReminders = try container.decodeIfPresent([TimedReminderItem].self, forKey: .timedReminders) ?? []
        backgroundColor = try container.decode(CodableColor.self, forKey: .backgroundColor)
        textColor = try container.decode(CodableColor.self, forKey: .textColor)
        reminderFontSize = try container.decodeIfPresent(Double.self, forKey: .reminderFontSize)
            ?? Self.defaultReminderFontSize
        reminderWidth = try container.decodeIfPresent(Double.self, forKey: .reminderWidth)
            ?? Self.defaultReminderWidth
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        let legacyBackgroundImageName = TimedReminderBackgroundImageReference.sanitized(
            try legacyContainer.decodeIfPresent(
                String.self,
                forKey: .timedReminderBackgroundImageName
            )
        )
        if let legacyBackgroundImageName {
            timedReminders = timedReminders.map { reminder in
                guard reminder.backgroundImageName == nil else { return reminder }
                var migratedReminder = reminder
                migratedReminder.backgroundImageName = legacyBackgroundImageName
                return migratedReminder
            }
        }
        isAlwaysOnTop = try container.decode(Bool.self, forKey: .isAlwaysOnTop)
        isOverlayVisible = try container.decode(Bool.self, forKey: .isOverlayVisible)
        residentReminderPosition = try container.decodeIfPresent(
            ResidentReminderPosition.self,
            forKey: .residentReminderPosition
        ) ?? .topRight
        savedWindowOrigin = try container.decodeIfPresent(SavedWindowOrigin.self, forKey: .savedWindowOrigin)
        displayLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .displayLanguage) ?? .system
    }
}

private extension CodableColor {
    func clamped() -> CodableColor {
        CodableColor(
            red: red.clamped(to: 0...1),
            green: green.clamped(to: 0...1),
            blue: blue.clamped(to: 0...1),
            alpha: alpha.clamped(to: 0...1)
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
