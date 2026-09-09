import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TimedReminderBackgroundGallery: View {
    @ObservedObject var store: ConfigurationStore
    @Binding var selection: String?
    let libraryRevision: Int
    let onLibraryChange: () -> Void
    @State private var entries: [TimedReminderBackgroundImageStore.Entry] = []
    @State private var errorMessage: String?
    @Environment(\.appLanguage) private var language
    private let imageStore = TimedReminderBackgroundImageStore.live

    private func localized(_ key: String, _ arguments: CVarArg...) -> String {
        AppLocalization.localized(key, language: language, arguments: arguments)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 14)], spacing: 16) {
                BackgroundThumbnail(
                    title: localized("无图片 · 渐变"),
                    image: nil,
                    isSelected: selection == nil,
                    select: { selection = nil }
                )

                ForEach(entries) { entry in
                    BackgroundThumbnail(
                        title: entry.displayName(language: language),
                        image: NSImage(contentsOf: entry.url),
                        isSelected: selection == entry.id,
                        select: { selection = entry.id },
                        remove: entry.isUserImage ? { confirmRemoval(entry) } : nil
                    )
                }

                BackgroundUploadCard(action: importImages)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
        .onAppear(perform: reload)
        .onChange(of: libraryRevision) { _, _ in reload() }
    }

    private func reload() {
        do {
            entries = try imageStore.entries()
        } catch {
            errorMessage = localized("无法读取背景图库：%@", error.localizedDescription)
        }
    }

    private func importImages() {
        let panel = NSOpenPanel()
        panel.title = localized("添加定时提醒背景")
        panel.prompt = localized("添加图片")
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }

        errorMessage = nil
        for url in panel.urls {
            do {
                let name = try imageStore.importImage(from: url)
                selection = name
            } catch {
                errorMessage = localized(
                    "无法添加“%@”：%@",
                    url.lastPathComponent,
                    localizedErrorDescription(error)
                )
                break
            }
        }
        reload()
        onLibraryChange()
    }

    private func confirmRemoval(_ entry: TimedReminderBackgroundImageStore.Entry) {
        let remindersUsingImage = store.timedReminders(usingBackgroundImageNamed: entry.id)
        guard remindersUsingImage.isEmpty else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = localized("图片正在使用，无法删除")
            let reminderNames = remindersUsingImage.prefix(3).map { reminder in
                reminder.text.isEmpty ? localized("未填写提醒") : reminder.text
            }
            let remainingCount = remindersUsingImage.count - reminderNames.count
            let joinedNames = reminderNames.joined(separator: language.resolved == .englishUS ? ", " : "、")
            alert.informativeText = remainingCount > 0
                ? localized("请先从“%@”等 %ld 条提醒中取消选择这张图片。", joinedNames, remindersUsingImage.count)
                : localized("请先从“%@”中取消选择这张图片。", joinedNames)
            alert.addButton(withTitle: localized("知道了"))
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = localized("删除这张背景图片？")
        alert.informativeText = localized("仅移除图库中的副本，原始图片会保留。")
        alert.addButton(withTitle: localized("删除"))
        alert.addButton(withTitle: localized("取消"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try imageStore.removeImage(named: entry.id)
            errorMessage = nil
            reload()
            onLibraryChange()
        } catch {
            errorMessage = localized("无法删除图片：%@", error.localizedDescription)
        }
    }

    private func localizedErrorDescription(_ error: Error) -> String {
        if
            let storeError = error as? TimedReminderBackgroundImageStore.StoreError,
            case .invalidImage = storeError
        {
            return localized("所选文件不是可读取的图片。")
        }
        return error.localizedDescription
    }
}

private struct BackgroundUploadCard: View {
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: action) {
                Color.orange.opacity(isHovering ? 0.09 : 0.035)
                    .aspectRatio(420.0 / 250.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        VStack(spacing: 7) {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .light))
                            Text("添加图片")
                                .font(.callout.weight(.medium))
                        }
                        .foregroundStyle(Color.orange)
                    }
                    .padding(3)
                    .overlay {
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(
                                Color.orange.opacity(isHovering ? 0.65 : 0.30),
                                style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                            )
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.localized("添加自定义背景图片"))
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.15), value: isHovering)

            Text("从本机选择")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 3)
        }
    }
}

private struct BackgroundThumbnail: View {
    let title: String
    let image: NSImage?
    let isSelected: Bool
    let select: () -> Void
    var remove: (() -> Void)?
    @State private var isHovering = false
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: select) {
                Color.clear
                    .aspectRatio(420.0 / 250.0, contentMode: .fit)
                    .overlay {
                        GeometryReader { geometry in
                            if let image {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                            } else {
                                LinearGradient(
                                    colors: [Color(red: 1, green: 0.84, blue: 0.36), Color(red: 1, green: 0.67, blue: 0.16)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .bottomTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Color.orange, in: Circle())
                                .padding(7)
                        }
                    }
                    .padding(3)
                    .overlay {
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(isSelected ? Color.orange : Color.secondary.opacity(isHovering ? 0.35 : 0.12), lineWidth: isSelected ? 2 : 1)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(language.localized(isSelected ? "已选择" : "未选择"))
            .overlay(alignment: .topTrailing) {
                if let remove {
                    Button(action: remove) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(BackgroundDeleteButtonStyle())
                    .padding(8)
                    .help(language.localized("删除图片"))
                    .accessibilityLabel(language.localized("删除上传的背景图片"))
                }
            }

            Text(title)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.orange : Color.secondary)
                .lineLimit(1)
                .padding(.horizontal, 3)
        }
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}

private struct BackgroundDeleteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DeleteButtonBody(configuration: configuration)
    }

    private struct DeleteButtonBody: View {
        let configuration: ButtonStyle.Configuration
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .foregroundStyle(isHovering ? Color.red : Color.secondary)
                .background(
                    isHovering
                        ? SettingsAppearancePalette.controlSurface
                        : SettingsAppearancePalette.windowBackground,
                    in: RoundedRectangle(cornerRadius: 7)
                )
                .scaleEffect(configuration.isPressed ? 0.94 : 1)
                .onHover { isHovering = $0 }
        }
    }
}
