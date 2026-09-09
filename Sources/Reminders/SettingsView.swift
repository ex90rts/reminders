import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    private static let contentBackgroundColor = Color(
        .sRGB,
        red: 245.0 / 255.0,
        green: 245.0 / 255.0,
        blue: 245.0 / 255.0,
        opacity: 1
    )

    private enum SettingsTab: String, CaseIterable, Identifiable {
        case residentReminders
        case timedReminders
        case appearanceSettings
        case about

        var id: Self { self }

        var title: String {
            switch self {
            case .residentReminders: "常驻提醒"
            case .timedReminders: "定时提醒"
            case .appearanceSettings: "外观设置"
            case .about: "关于"
            }
        }

        var systemImage: String {
            switch self {
            case .residentReminders: "note.text"
            case .timedReminders: "alarm"
            case .appearanceSettings: "paintpalette"
            case .about: "info.circle"
            }
        }
    }

    @ObservedObject var store: ConfigurationStore
    let resetPosition: () -> Void
    var previewTimedReminder: (TimedReminderItem) -> Void = { _ in }
    @State private var selectedTab: SettingsTab = .residentReminders
    @State private var soundPreview: NSSound?
    @State private var soundPreviewCompletionTimer: Timer?
    @State private var previewingReminderID: TimedReminderItem.ID?
    @State private var expandedBackgroundReminderIDs: Set<TimedReminderItem.ID> = []
    @State private var backgroundLibraryRevision = 0
    @State private var backgroundImageDisplayNames: [String: String] = [:]
    private let backgroundImageStore = TimedReminderBackgroundImageStore.live

    var body: some View {
        VStack(spacing: 0) {
            settingsTabBar

            Divider()
                .opacity(0.55)

            ScrollView {
                selectedTabContent
                    .id(selectedTab)
                    .frame(maxWidth: 900, alignment: .topLeading)
                    .padding(.horizontal, 26)
                    .padding(.top, 24)
                    .padding(.bottom, 30)
            }
            .background(Self.contentBackgroundColor)
        }
        .frame(minWidth: 720, minHeight: 560)
        .tint(.orange)
        .background(Color(nsColor: .windowBackgroundColor))
        .onDisappear {
            stopSoundPreview()
        }
        .onAppear(perform: reloadBackgroundImageDisplayNames)
    }

    private var settingsTabBar: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selectedTab == tab ? Color.orange : Color.secondary)

                        Text(tab.title)
                            .font(.system(size: 13, weight: .semibold))

                        if let count = tabCount(for: tab) {
                            Text("\(count)")
                                .font(.caption2.monospacedDigit().weight(.bold))
                                .foregroundStyle(selectedTab == tab ? Color.orange : Color.secondary)
                                .padding(.horizontal, 6)
                                .frame(minHeight: 18)
                                .background(
                                    selectedTab == tab
                                        ? Color.orange.opacity(0.13)
                                        : Color.secondary.opacity(0.09),
                                    in: Capsule()
                                )
                        }
                    }
                    .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .contentShape(Rectangle())
                    .background {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(
                                selectedTab == tab
                                    ? Color(nsColor: .windowBackgroundColor)
                                    : Color.clear
                            )
                    }
                    .overlay {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(Color.orange.opacity(0.20), lineWidth: 1)
                        }
                    }
                    .shadow(
                        color: .black.opacity(selectedTab == tab ? 0.07 : 0),
                        radius: 4,
                        y: 1
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityValue(selectedTab == tab ? "已选择" : "未选择")
            }
        }
        .padding(4)
        .background(
            Color.secondary.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.secondary.opacity(0.10), lineWidth: 1)
        }
        .padding(.horizontal, 26)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .residentReminders:
            residentRemindersPage
                .transition(.opacity)
        case .timedReminders:
            timedRemindersPage
                .transition(.opacity)
        case .appearanceSettings:
            appearanceSettingsPage
                .transition(.opacity)
        case .about:
            aboutPage
                .transition(.opacity)
        }
    }

    private func tabCount(for tab: SettingsTab) -> Int? {
        switch tab {
        case .residentReminders:
            store.configuration.items.count
        case .timedReminders:
            store.configuration.timedReminders.count
        case .appearanceSettings, .about:
            nil
        }
    }

    private var timedRemindersPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            collectionPageHeader(
                title: "定时提醒",
                count: store.configuration.timedReminders.count,
                actionTitle: "添加定时提醒",
                action: { store.addTimedReminder() }
            )

            VStack(spacing: 10) {
                if store.configuration.timedReminders.isEmpty {
                    emptyState(title: "暂无定时提醒", systemImage: "clock.badge.questionmark")
                } else {
                    ForEach(store.configuration.timedReminders) { reminder in
                        timedReminderEditor(reminder)
                    }
                }
            }
        }
    }

    private func timedReminderEditor(_ reminder: TimedReminderItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                editorFieldLabel("内容")

                TextField(
                    "提醒内容",
                    text: timedReminderBinding(for: reminder, keyPath: \.text),
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)

                Toggle(
                    "启用定时提醒",
                    isOn: timedReminderBinding(for: reminder, keyPath: \.isEnabled)
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .help(reminder.isEnabled ? "停用此定时提醒" : "启用此定时提醒")
                .accessibilityLabel(reminder.isEnabled ? "停用此定时提醒" : "启用此定时提醒")

                Button(role: .destructive) {
                    confirmTimedReminderDeletion(of: reminder)
                } label: {
                    itemActionIcon("trash")
                }
                .buttonStyle(HoverActionButtonStyle(isDestructive: true))
                .help("删除")
            }

            HStack(alignment: .top, spacing: 12) {
                editorFieldLabel("重复")
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 10) {
                    Picker(
                        "重复",
                        selection: timedReminderFrequencyBinding(for: reminder)
                    ) {
                        ForEach(TimedReminderFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.title).tag(frequency)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize(horizontal: true, vertical: false)

                    recurrenceDetails(for: reminder)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer(minLength: 0)
            }

            HStack(alignment: .center, spacing: 12) {
                editorFieldLabel("铃声")

                HStack(spacing: 4) {
                    Picker(
                        "铃声",
                        selection: timedReminderSoundBinding(for: reminder)
                    ) {
                        Text("无铃声").tag(Optional<String>.none)

                        if let selectedSound = reminder.soundName,
                           !SystemSoundLibrary.availableNames.contains(selectedSound) {
                            Divider()

                            Text(SystemSoundLibrary.displayName(for: selectedSound))
                                .tag(Optional(selectedSound))
                        }

                        if !SystemSoundLibrary.availableSounds.isEmpty {
                            Divider()

                            ForEach(SystemSoundLibrary.availableSounds) { sound in
                                Text(sound.displayName).tag(Optional(sound.id))
                            }
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel("提醒铃声")

                    let isPreviewing = previewingReminderID == reminder.id
                    Button {
                        toggleSoundPreview(for: reminder)
                    } label: {
                        itemActionIcon(isPreviewing ? "stop.fill" : "play.fill")
                    }
                    .buttonStyle(HoverActionButtonStyle())
                    .disabled(currentSoundName(for: reminder) == nil)
                    .help(isPreviewing ? "停止播放" : "播放铃声")
                    .accessibilityLabel(isPreviewing ? "停止播放铃声" : "播放铃声")
                }

                Spacer(minLength: 0)
            }

            timedReminderBackgroundSection(for: reminder)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(0.72),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.16), value: reminder.frequency)
    }

    private func timedReminderBackgroundSection(for reminder: TimedReminderItem) -> some View {
        let isExpanded = expandedBackgroundReminderIDs.contains(reminder.id)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                editorFieldLabel("背景")

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        if isExpanded {
                            expandedBackgroundReminderIDs.remove(reminder.id)
                        } else {
                            expandedBackgroundReminderIDs.insert(reminder.id)
                        }
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))

                        Text(backgroundSelectionSummary(for: reminder))
                            .font(.callout)
                    }
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "折叠背景设置" : "展开背景设置")

                Spacer(minLength: 0)

                Button {
                    let currentReminder = store.configuration.timedReminders
                        .first(where: { $0.id == reminder.id }) ?? reminder
                    previewTimedReminder(currentReminder)
                } label: {
                    Label("预览", systemImage: "play.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("预览这条提醒最终弹出的效果")
                .accessibilityLabel("预览这条定时提醒")
            }

            if isExpanded {
                TimedReminderBackgroundGallery(
                    store: store,
                    selection: timedReminderBinding(for: reminder, keyPath: \.backgroundImageName),
                    libraryRevision: backgroundLibraryRevision,
                    onLibraryChange: backgroundLibraryDidChange
                )
                .padding(.leading, 50)
                .padding(.top, 12)
                .transition(.identity)
            }
        }
        .clipped()
    }

    private func backgroundSelectionSummary(for reminder: TimedReminderItem) -> String {
        guard let imageName = reminder.backgroundImageName else { return "无图片 · 渐变" }
        return backgroundImageDisplayNames[imageName] ?? "已选择背景图"
    }

    private func backgroundLibraryDidChange() {
        backgroundLibraryRevision += 1
        reloadBackgroundImageDisplayNames()
    }

    private func reloadBackgroundImageDisplayNames() {
        guard let entries = try? backgroundImageStore.entries() else { return }
        backgroundImageDisplayNames = Dictionary(
            uniqueKeysWithValues: entries.map { ($0.id, $0.displayName) }
        )
    }

    @ViewBuilder
    private func recurrenceDetails(for reminder: TimedReminderItem) -> some View {
        switch reminder.frequency {
        case .hourlyInterval:
            recurrenceDetailSurface(systemImage: "clock.arrow.circlepath") {
                recurrenceControlGroup("起始时间") {
                    reminderTimePicker(for: reminder, accessibilityLabel: "开始时间")
                }
                recurrenceDetailDivider
                recurrenceControlGroup("提醒间隔") {
                    intervalControl(for: reminder)
                }
            }

        case .daily:
            recurrenceDetailSurface(systemImage: "clock") {
                recurrenceControlGroup("提醒时间") {
                    reminderTimePicker(for: reminder, accessibilityLabel: "每天提醒时间")
                }
            }

        case .selectedWeekdays:
            recurrenceDetailSurface(systemImage: "calendar") {
                recurrenceControlGroup("提醒时间") {
                    reminderTimePicker(for: reminder, accessibilityLabel: "指定星期提醒时间")
                }
                recurrenceDetailDivider
                recurrenceControlGroup("提醒星期") {
                    HStack(spacing: 5) {
                        ForEach(ReminderWeekday.allCases, id: \.self) { weekday in
                            weekdayButton(weekday, reminder: reminder)
                        }
                    }
                }
            }

        case .monthly:
            recurrenceDetailSurface(systemImage: "calendar.circle") {
                recurrenceControlGroup("提醒时间") {
                    reminderTimePicker(for: reminder, accessibilityLabel: "每月提醒时间")
                }
                recurrenceDetailDivider
                recurrenceControlGroup("提醒日期") {
                    MonthlyDayPickerButton(selectedDays: reminder.monthlyDays) { day in
                        store.toggleTimedReminderMonthlyDay(id: reminder.id, day: day)
                    }
                }
            }

        case .specificDate:
            recurrenceDetailSurface(systemImage: "calendar.badge.clock") {
                recurrenceControlGroup("提醒时间") {
                    specificDatePicker(for: reminder)
                }
            }
        }
    }

    private func recurrenceDetailSurface<Content: View>(
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))

            content()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.secondary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(.separator.opacity(0.32), lineWidth: 1)
        }
    }

    private func recurrenceDetailLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func recurrenceControlGroup<Control: View>(
        _ title: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 5) {
            recurrenceDetailLabel(title)
            control()
        }
    }

    private var recurrenceDetailDivider: some View {
        Divider()
            .frame(height: 20)
            .padding(.horizontal, 2)
    }

    private func intervalControl(for reminder: TimedReminderItem) -> some View {
        HStack(spacing: 0) {
            intervalAdjustmentButton(
                systemImage: "minus",
                accessibilityLabel: "缩短提醒间隔",
                isDisabled: reminder.intervalHours <= TimedReminderItem.intervalHoursRange.lowerBound
            ) {
                updateInterval(for: reminder, by: -1)
            }

            Divider()
                .frame(height: 18)

            Text("\(reminder.intervalHours) 小时")
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .frame(minWidth: 58)

            Divider()
                .frame(height: 18)

            intervalAdjustmentButton(
                systemImage: "plus",
                accessibilityLabel: "延长提醒间隔",
                isDisabled: reminder.intervalHours >= TimedReminderItem.intervalHoursRange.upperBound
            ) {
                updateInterval(for: reminder, by: 1)
            }
        }
        .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(.separator.opacity(0.48), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func intervalAdjustmentButton(
        systemImage: String,
        accessibilityLabel: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 27, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDisabled ? Color.secondary.opacity(0.35) : Color.primary)
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel)
    }

    private func updateInterval(for reminder: TimedReminderItem, by offset: Int) {
        let binding = timedReminderBinding(for: reminder, keyPath: \.intervalHours)
        binding.wrappedValue = min(
            max(
                binding.wrappedValue + offset,
                TimedReminderItem.intervalHoursRange.lowerBound
            ),
            TimedReminderItem.intervalHoursRange.upperBound
        )
    }

    private func reminderTimePicker(
        for reminder: TimedReminderItem,
        accessibilityLabel: String
    ) -> some View {
        GraphicalTimePickerButton(
            selection: timedReminderTimeBinding(for: reminder),
            accessibilityLabel: accessibilityLabel
        )
    }

    private func specificDatePicker(for reminder: TimedReminderItem) -> some View {
        GraphicalDateTimePickerButton(
            selection: specificDateBinding(for: reminder),
            accessibilityLabel: "指定日期提醒时间"
        )
    }

    private func weekdayButton(
        _ weekday: ReminderWeekday,
        reminder: TimedReminderItem
    ) -> some View {
        let isSelected = reminder.selectedWeekdays.contains(weekday)
        return Button {
            store.toggleTimedReminderWeekday(id: reminder.id, weekday: weekday)
        } label: {
            Text(weekday.shortTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .frame(width: 26, height: 24)
                .background(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.20), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help("周\(weekday.shortTitle)")
        .accessibilityLabel("周\(weekday.shortTitle)")
        .accessibilityValue(isSelected ? "已选择" : "未选择")
    }

    private var residentRemindersPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            collectionPageHeader(
                title: "常驻提醒",
                count: store.configuration.items.count,
                actionTitle: "添加常驻提醒",
                action: store.addItem
            )

            VStack(spacing: 10) {
                if store.configuration.items.isEmpty {
                    emptyState(title: "暂无常驻提醒", systemImage: "note.text.badge.plus")
                } else {
                    ForEach(Array(store.configuration.items.enumerated()), id: \.element.id) { index, item in
                        itemEditor(item, index: index)
                    }
                }
            }
        }
    }

    private func itemEditor(_ item: ReminderItem, index: Int) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(index + 1)")
                .font(.caption.weight(.bold))
                .foregroundStyle(item.isVisible ? Color.orange : Color.secondary)
                .opacity(item.isVisible ? 1 : 0.45)
                .frame(width: 28, height: 28)
                .background(
                    item.isVisible ? Color.orange.opacity(0.12) : Color.secondary.opacity(0.10),
                    in: Circle()
                )

            TextField("提醒内容", text: binding(for: item.id), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .opacity(item.isVisible ? 1 : 0.55)
                .accessibilityLabel("第 \(index + 1) 个常驻提醒")

            HStack(spacing: 3) {
                Button {
                    store.toggleItemVisibility(id: item.id)
                } label: {
                    itemActionIcon(item.isVisible ? "eye" : "eye.slash")
                }
                .buttonStyle(HoverActionButtonStyle())
                .help(item.isVisible ? "隐藏此提醒" : "显示此提醒")
                .accessibilityLabel(item.isVisible ? "隐藏第 \(index + 1) 个提醒" : "显示第 \(index + 1) 个提醒")

                Divider()
                    .frame(height: 18)
                    .padding(.horizontal, 3)

                Button {
                    store.moveItem(id: item.id, offset: -1)
                } label: {
                    itemActionIcon("chevron.up")
                }
                .buttonStyle(HoverActionButtonStyle())
                .disabled(index == 0)
                .help("上移")

                Button {
                    store.moveItem(id: item.id, offset: 1)
                } label: {
                    itemActionIcon("chevron.down")
                }
                .buttonStyle(HoverActionButtonStyle())
                .disabled(index == store.configuration.items.count - 1)
                .help("下移")

                Button(role: .destructive) {
                    confirmDeletion(of: item)
                } label: {
                    itemActionIcon("trash")
                }
                .buttonStyle(HoverActionButtonStyle(isDestructive: true))
                .help("删除")
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(0.72),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }
    }

    private var appearanceSettingsPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                pageHeader("常驻提醒外观")

                settingsSurface {
                    settingRow(systemImage: "paintpalette.fill", title: "贴纸配色") {
                        HStack(spacing: 22) {
                            ColorPicker("背景颜色", selection: backgroundColorBinding, supportsOpacity: true)
                            ColorPicker("文字颜色", selection: textColorBinding, supportsOpacity: true)
                        }
                    }

                    settingsRowDivider

                    settingRow(systemImage: "textformat.size", title: "文字大小") {
                        Slider(
                            value: $store.configuration.reminderFontSize,
                            in: AppConfiguration.reminderFontSizeRange,
                            onEditingChanged: { isEditing in
                                guard !isEditing else { return }
                                store.configuration.reminderFontSize =
                                    store.configuration.reminderFontSize.rounded()
                            }
                        )
                        .frame(maxWidth: 280)
                        Text("\(Int(store.configuration.reminderFontSize.rounded())) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 52, alignment: .trailing)
                    }

                    settingsRowDivider

                    settingRow(systemImage: "arrow.left.and.right", title: "贴纸宽度") {
                        Slider(
                            value: $store.configuration.reminderWidth,
                            in: AppConfiguration.reminderWidthRange,
                            onEditingChanged: { isEditing in
                                guard !isEditing else { return }
                                store.configuration.reminderWidth =
                                    store.configuration.reminderWidth.rounded()
                            }
                        )
                        .frame(maxWidth: 280)
                        Text("\(Int(store.configuration.reminderWidth.rounded())) px")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 52, alignment: .trailing)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                pageHeader("常驻提醒位置")

                settingsSurface {
                    settingRow(systemImage: "pin.fill", title: "始终显示在所有普通窗口上方") {
                        Toggle("", isOn: $store.configuration.isAlwaysOnTop)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    settingsRowDivider

                    settingRow(systemImage: "eye.fill", title: "显示/隐藏常驻提醒") {
                        Toggle("", isOn: $store.configuration.isOverlayVisible)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    settingsRowDivider

                    settingRow(systemImage: "location.fill", title: "常驻提醒显示位置") {
                        HStack(spacing: 4) {
                            Picker(
                                "常驻提醒显示位置",
                                selection: residentReminderPositionBinding
                            ) {
                                ForEach(ResidentReminderPosition.allCases) { position in
                                    Text(position.title).tag(position)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .overlay {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(Color.orange, lineWidth: 1)
                            }

                            Button {
                                resetPosition()
                            } label: {
                                itemActionIcon("arrow.counterclockwise")
                            }
                            .buttonStyle(HoverActionButtonStyle())
                            .premiumTooltip("恢复默认位置")
                            .accessibilityLabel("恢复默认位置")
                            .zIndex(10)
                        }
                    }
                }
            }
        }
    }

    private var aboutPage: some View {
        VStack(spacing: 22) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 112, height: 112)
                .accessibilityLabel("清醒贴应用图标")

            VStack(spacing: 7) {
                Text(appDisplayName)
                    .font(.largeTitle.weight(.bold))
                    .tracking(-0.5)

                Text(appVersionDescription)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text("把重要的行为提示留在桌面上，并在恰当的时间主动提醒你。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)

            settingsSurface {
                aboutFeatureRow(
                    systemImage: "note.text",
                    title: "常驻提醒",
                    description: "将多条提示固定在桌面，随时保持可见。"
                )

                settingsRowDivider

                aboutFeatureRow(
                    systemImage: "alarm.fill",
                    title: "定时提醒",
                    description: "按小时、每天、指定星期、每月或指定日期弹出提醒。"
                )

                settingsRowDivider

                aboutFeatureRow(
                    systemImage: "paintpalette.fill",
                    title: "个性化外观",
                    description: "自定义贴纸样式，并为每条定时提醒选择背景。"
                )
            }
            .frame(maxWidth: 600)
        }
        .frame(maxWidth: .infinity, minHeight: 450, alignment: .top)
        .padding(.top, 18)
    }

    private func aboutFeatureRow(
        systemImage: String,
        title: String,
        description: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.orange)
                .frame(width: 32, height: 32)
                .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
    }

    private var appDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "清醒贴"
    }

    private var appVersionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        return switch (version, build) {
        case let (version?, build?):
            "版本 \(version)（构建 \(build)）"
        case let (version?, nil):
            "版本 \(version)"
        case let (nil, build?):
            "构建 \(build)"
        case (nil, nil):
            "版本信息不可用"
        }
    }

    private func pageHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .tracking(-0.2)
    }

    private func collectionPageHeader(
        title: String,
        count: Int,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            pageHeader(title)

            Text("\(count) 项")
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(Color.orange)
                .padding(.horizontal, 8)
                .frame(minHeight: 22)
                .background(Color.orange.opacity(0.13), in: Capsule())

            Spacer()

            Button(action: action) {
                Label(actionTitle, systemImage: "plus")
                    .font(.callout.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.orange)
        }
    }

    private func settingsSurface<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(0.66),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.secondary.opacity(0.11), lineWidth: 1)
        }
    }

    private func settingRow<Control: View>(
        systemImage: String,
        title: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.orange)
                .frame(width: 30, height: 30)
                .background(
                    Color.orange.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            Text(title)
                .font(.callout.weight(.medium))
                .lineLimit(1)

            Spacer(minLength: 24)

            control()
        }
        .frame(maxWidth: .infinity, minHeight: 54)
    }

    private var settingsRowDivider: some View {
        Divider()
            .padding(.leading, 44)
            .opacity(0.55)
    }

    private func editorFieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(width: 38, alignment: .trailing)
    }

    private func emptyState(title: String, systemImage: String) -> some View {
        VStack(spacing: 11) {
            Image(systemName: systemImage)
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(Color.orange.opacity(0.82))
                .frame(width: 48, height: 48)
                .background(
                    Color.orange.opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )

            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 172)
        .background(
            Color.secondary.opacity(0.026),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    Color.orange.opacity(0.18),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 5])
                )
        }
        .accessibilityElement(children: .combine)
    }

    private func itemActionIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
    }

    private func confirmDeletion(of item: ReminderItem) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "删除常驻提醒？"
        let displayText = item.text.isEmpty ? "未填写提醒" : item.text
        alert.informativeText = "“\(displayText)”删除后无法恢复。"
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        store.removeItem(id: item.id)
    }

    private func confirmTimedReminderDeletion(of reminder: TimedReminderItem) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "删除定时提醒？"
        let displayText = reminder.text.isEmpty ? "未填写提醒" : reminder.text
        alert.informativeText = "“\(displayText)”删除后无法恢复。"
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        store.removeTimedReminder(id: reminder.id)
    }

    private func binding(for id: ReminderItem.ID) -> Binding<String> {
        Binding(
            get: {
                store.configuration.items.first(where: { $0.id == id })?.text ?? ""
            },
            set: { newText in
                guard let index = store.configuration.items.firstIndex(where: { $0.id == id }) else { return }
                store.configuration.items[index].text = newText
            }
        )
    }

    func timedReminderBinding<Value>(
        for reminder: TimedReminderItem,
        keyPath: WritableKeyPath<TimedReminderItem, Value>
    ) -> Binding<Value> {
        Binding(
            get: {
                store.configuration.timedReminders
                    .first(where: { $0.id == reminder.id })?[keyPath: keyPath]
                    ?? reminder[keyPath: keyPath]
            },
            set: { newValue in
                guard let index = store.configuration.timedReminders.firstIndex(where: { $0.id == reminder.id }) else {
                    return
                }
                store.configuration.timedReminders[index][keyPath: keyPath] = newValue
            }
        )
    }

    private func timedReminderSoundBinding(
        for reminder: TimedReminderItem
    ) -> Binding<String?> {
        let configurationBinding = timedReminderBinding(
            for: reminder,
            keyPath: \.soundName
        )

        return Binding(
            get: { configurationBinding.wrappedValue },
            set: { selectedSound in
                stopSoundPreview()
                configurationBinding.wrappedValue = selectedSound
            }
        )
    }

    private func currentSoundName(for reminder: TimedReminderItem) -> String? {
        store.configuration.timedReminders
            .first(where: { $0.id == reminder.id })?
            .soundName
    }

    private func toggleSoundPreview(for reminder: TimedReminderItem) {
        if previewingReminderID == reminder.id {
            stopSoundPreview()
            return
        }

        stopSoundPreview()
        guard let name = currentSoundName(for: reminder),
              let preview = SystemSoundLibrary.sound(named: name) else { return }

        preview.loops = false
        preview.currentTime = 0
        preview.play()
        soundPreview = preview
        previewingReminderID = reminder.id

        let completionTimer = Timer(
            timeInterval: max(preview.duration, 0.1) + 0.1,
            repeats: false
        ) { _ in
            guard soundPreview === preview else { return }
            stopSoundPreview()
        }
        RunLoop.main.add(completionTimer, forMode: .common)
        soundPreviewCompletionTimer = completionTimer
    }

    private func stopSoundPreview() {
        soundPreviewCompletionTimer?.invalidate()
        soundPreviewCompletionTimer = nil
        soundPreview?.stop()
        soundPreview = nil
        previewingReminderID = nil
    }

    private func timedReminderTimeBinding(for reminder: TimedReminderItem) -> Binding<Date> {
        Binding(
            get: {
                let currentReminder = store.configuration.timedReminders
                    .first(where: { $0.id == reminder.id }) ?? reminder
                return Calendar.autoupdatingCurrent.date(
                    bySettingHour: currentReminder.hour,
                    minute: currentReminder.minute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { date in
                guard let index = store.configuration.timedReminders.firstIndex(where: { $0.id == reminder.id }) else {
                    return
                }
                let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
                store.configuration.timedReminders[index].hour = components.hour ?? 0
                store.configuration.timedReminders[index].minute = components.minute ?? 0
            }
        )
    }

    private func timedReminderFrequencyBinding(
        for reminder: TimedReminderItem
    ) -> Binding<TimedReminderFrequency> {
        Binding(
            get: {
                store.configuration.timedReminders
                    .first(where: { $0.id == reminder.id })?.frequency ?? reminder.frequency
            },
            set: { frequency in
                guard let index = store.configuration.timedReminders.firstIndex(where: { $0.id == reminder.id }) else {
                    return
                }

                store.configuration.timedReminders[index].frequency = frequency
                guard frequency == .specificDate else { return }

                let currentReminder = store.configuration.timedReminders[index]
                if currentReminder.specificDate.map({ $0 > Date() }) == true { return }
                store.configuration.timedReminders[index].specificDate = nextSpecificDate(
                    hour: currentReminder.hour,
                    minute: currentReminder.minute
                )
            }
        )
    }

    private func specificDateBinding(for reminder: TimedReminderItem) -> Binding<Date> {
        Binding(
            get: {
                let currentReminder = store.configuration.timedReminders
                    .first(where: { $0.id == reminder.id }) ?? reminder
                return currentReminder.specificDate
                    ?? nextSpecificDate(hour: currentReminder.hour, minute: currentReminder.minute)
            },
            set: { date in
                guard let index = store.configuration.timedReminders.firstIndex(where: { $0.id == reminder.id }) else {
                    return
                }
                let calendar = Calendar.autoupdatingCurrent
                let components = calendar.dateComponents([.hour, .minute], from: date)
                let normalizedDate = calendar.date(bySetting: .second, value: 0, of: date) ?? date
                store.configuration.timedReminders[index].specificDate = normalizedDate
                store.configuration.timedReminders[index].hour = components.hour ?? 0
                store.configuration.timedReminders[index].minute = components.minute ?? 0
            }
        )
    }

    private func nextSpecificDate(hour: Int, minute: Int, now: Date = Date()) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: now
        ) ?? now
        if today > now { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? now.addingTimeInterval(86_400)
    }

    private var backgroundColorBinding: Binding<Color> {
        Binding(
            get: { store.configuration.backgroundColor.color },
            set: { store.configuration.backgroundColor = CodableColor($0) }
        )
    }

    private var textColorBinding: Binding<Color> {
        Binding(
            get: { store.configuration.textColor.color },
            set: { store.configuration.textColor = CodableColor($0) }
        )
    }

    private var residentReminderPositionBinding: Binding<ResidentReminderPosition> {
        Binding(
            get: { store.configuration.residentReminderPosition },
            set: { store.selectResidentReminderPosition($0) }
        )
    }
}

private struct HoverActionButtonStyle: ButtonStyle {
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        HoverActionButtonStyleBody(
            configuration: configuration,
            isDestructive: isDestructive
        )
    }
}

private struct HoverActionButtonStyleBody: View {
    let configuration: ButtonStyle.Configuration
    let isDestructive: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    var body: some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(backgroundColor)
            }
            .scaleEffect(configuration.isPressed && isEnabled ? 0.94 : 1)
            .opacity(isEnabled ? 1 : 0.36)
            .animation(.easeOut(duration: 0.14), value: isHovering)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .onHover { isHovering = $0 }
    }

    private var foregroundColor: Color {
        if isDestructive && isHovering && isEnabled {
            return .red
        }
        return .secondary
    }

    private var backgroundColor: Color {
        guard isEnabled else { return .clear }
        if configuration.isPressed {
            return Color.secondary.opacity(0.17)
        }
        return isHovering ? Color.secondary.opacity(0.11) : .clear
    }
}

private extension View {
    func premiumTooltip(_ text: String) -> some View {
        modifier(PremiumTooltipModifier(text: text))
    }
}

private struct PremiumTooltipModifier: ViewModifier {
    let text: String

    @State private var isPresented = false
    @State private var pendingPresentation: DispatchWorkItem?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if isPresented {
                    PremiumTooltipBubble(text: text)
                        .fixedSize()
                        .offset(y: -36)
                        .transition(
                            .opacity.combined(
                                with: .scale(scale: 0.94, anchor: .bottomTrailing)
                            )
                        )
                        .allowsHitTesting(false)
                }
            }
            .onHover(perform: handleHover)
            .onDisappear {
                pendingPresentation?.cancel()
            }
    }

    private func handleHover(_ isHovering: Bool) {
        pendingPresentation?.cancel()

        guard isHovering else {
            withAnimation(.easeOut(duration: 0.12)) {
                isPresented = false
            }
            return
        }

        let presentation = DispatchWorkItem {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                isPresented = true
            }
        }
        pendingPresentation = presentation
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.32,
            execute: presentation
        )
    }
}

private struct PremiumTooltipBubble: View {
    let text: String

    private let backgroundColor = Color(
        .sRGB,
        red: 0.12,
        green: 0.105,
        blue: 0.09,
        opacity: 0.96
    )

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.96))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                backgroundColor,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.orange.opacity(0.28), lineWidth: 0.75)
            }
            .shadow(color: .black.opacity(0.20), radius: 8, y: 3)
            .accessibilityHidden(true)
    }
}

private struct MonthlyDayPickerButton: View {
    let selectedDays: Set<MonthlyReminderDay>
    let toggleDay: (MonthlyReminderDay) -> Void

    @State private var isPickerPresented = false

    private let numberedDayRows = [
        Array(1...7),
        Array(8...14),
        Array(15...21),
        Array(22...28),
        Array(29...31),
    ]

    var body: some View {
        Button {
            isPickerPresented = true
        } label: {
            HStack(spacing: 6) {
                Text(selectionSummary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .truncationMode(.middle)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 76, maxWidth: 200, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("每月提醒日期")
        .accessibilityValue(accessibilitySelectionSummary)
        .popover(isPresented: $isPickerPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("选择每月提醒日期")
                        .font(.headline)

                    Text("可多选，当月没有该日期则自动跳过")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(numberedDayRows.indices, id: \.self) { rowIndex in
                        HStack(spacing: 6) {
                            ForEach(numberedDayRows[rowIndex], id: \.self) { day in
                                dayButton(.day(day))
                            }

                            if rowIndex == numberedDayRows.count - 1 {
                                dayButton(.lastDay, horizontalPadding: 10)
                            }
                        }
                    }
                }

                Divider()

                HStack {
                    Text("已选择 \(selectedDays.count) 项")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("完成") {
                        isPickerPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(14)
            .frame(width: 274)
        }
    }

    private var selectionSummary: String {
        var components: [String] = []
        let numberedDays = selectedDays
            .filter { MonthlyReminderDay.numberedDayRange.contains($0.rawValue) }
            .map(\.rawValue)
            .sorted()

        if !numberedDays.isEmpty {
            components.append("\(numberedDays.map(String.init).joined(separator: ",")) 号")
        }
        if selectedDays.contains(.lastDay) {
            components.append(MonthlyReminderDay.lastDay.title)
        }

        return components.isEmpty ? "选择日期" : components.joined(separator: ",")
    }

    private var accessibilitySelectionSummary: String {
        selectedDays
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.title)
            .joined(separator: "、")
    }

    private func dayButton(
        _ day: MonthlyReminderDay,
        horizontalPadding: CGFloat = 0
    ) -> some View {
        let isSelected = selectedDays.contains(day)
        return Button {
            toggleDay(day)
        } label: {
            Text(pickerTitle(for: day))
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .frame(minWidth: 30, minHeight: 28)
                .padding(.horizontal, horizontalPadding)
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 7)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.20), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help(day.title)
        .accessibilityLabel(day.title)
        .accessibilityValue(isSelected ? "已选择" : "未选择")
    }

    private func pickerTitle(for day: MonthlyReminderDay) -> String {
        guard MonthlyReminderDay.numberedDayRange.contains(day.rawValue) else {
            return day.title
        }
        return String(day.rawValue)
    }
}

private struct GraphicalTimePickerButton: View {
    @Binding var selection: Date
    let accessibilityLabel: String

    @State private var isPickerPresented = false

    var body: some View {
        Button {
            isPickerPresented = true
        } label: {
            HStack(spacing: 6) {
                Text(selection.formatted(date: .omitted, time: .shortened))
                    .monospacedDigit()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 66)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(selection.formatted(date: .omitted, time: .shortened))
        .popover(isPresented: $isPickerPresented, arrowEdge: .bottom) {
            VStack(spacing: 12) {
                DatePicker(
                    accessibilityLabel,
                    selection: $selection,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.graphical)

                Divider()

                HStack {
                    Text("选择提醒时间")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("完成") {
                        isPickerPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(14)
            .frame(minWidth: 250)
        }
    }
}

private struct GraphicalDateTimePickerButton: View {
    @Binding var selection: Date
    let accessibilityLabel: String

    @State private var isPickerPresented = false

    var body: some View {
        Button {
            isPickerPresented = true
        } label: {
            HStack(spacing: 6) {
                Text(selection.formatted(date: .abbreviated, time: .shortened))
                    .monospacedDigit()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(selection.formatted(date: .long, time: .shortened))
        .popover(isPresented: $isPickerPresented, arrowEdge: .bottom) {
            VStack(spacing: 12) {
                DatePicker(
                    accessibilityLabel,
                    selection: $selection,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.graphical)

                Divider()

                HStack {
                    Text("选择提醒日期和时间")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("完成") {
                        isPickerPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(14)
            .frame(minWidth: 300)
        }
    }
}
