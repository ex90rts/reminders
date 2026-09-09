import AppKit
import Foundation

enum TimedReminderBackgroundImageReference {
    static let builtInPrefix = "builtin:"

    static func sanitized(_ imageName: String?) -> String? {
        guard let imageName else { return nil }
        let trimmedName = imageName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        if trimmedName.hasPrefix(builtInPrefix) {
            let filename = String(trimmedName.dropFirst(builtInPrefix.count))
            return isFilename(filename) ? trimmedName : nil
        }
        return isFilename(trimmedName) ? trimmedName : nil
    }

    static func builtInFilename(from imageName: String) -> String? {
        guard imageName.hasPrefix(builtInPrefix) else { return nil }
        let filename = String(imageName.dropFirst(builtInPrefix.count))
        return isFilename(filename) ? filename : nil
    }

    private static func isFilename(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".."
            && !name.contains("/") && !name.contains("\\")
            && name == URL(fileURLWithPath: name).lastPathComponent
    }
}

struct TimedReminderBackgroundImageStore {
    struct Entry: Identifiable {
        let id: String
        let url: URL
        let isUserImage: Bool
        let ordinal: Int

        var displayName: String {
            displayName(language: .simplifiedChinese)
        }

        func displayName(language: AppLanguage) -> String {
            language.localized(
                isUserImage ? "自定义图片 #%ld" : "系统内置 #%ld",
                ordinal
            )
        }
    }

    enum StoreError: LocalizedError {
        case invalidImage

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                "所选文件不是可读取的图片。"
            }
        }
    }

    static let live = TimedReminderBackgroundImageStore(
        directoryURL: FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent(
            Bundle.main.bundleIdentifier ?? "com.webber.reminders",
            isDirectory: true
        )
        .appendingPathComponent("TimedReminderBackgrounds", isDirectory: true)
    )

    let directoryURL: URL
    var builtInDirectoryURL: URL? = Bundle.main.resourceURL?.appendingPathComponent("AlarmBg")
    private var importOrderURL: URL {
        directoryURL.appendingPathComponent(".import-order.json")
    }

    func entries() throws -> [Entry] {
        let builtIns = try imageURLs(in: builtInDirectoryURL)
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
            .enumerated().map { index, url in
                Entry(
                    id: TimedReminderBackgroundImageReference.builtInPrefix + url.lastPathComponent,
                    url: url,
                    isUserImage: false,
                    ordinal: index + 1
                )
            }
        let uploads = try orderedUserImageURLs()
            .enumerated().map { index, url in
                Entry(
                    id: url.lastPathComponent,
                    url: url,
                    isUserImage: true,
                    ordinal: index + 1
                )
            }
        return builtIns + uploads
    }

    private func imageURLs(in directory: URL?) throws -> [URL] {
        guard let directory,
              FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let resourceKeys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .creationDateKey,
            .contentModificationDateKey,
        ]
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        )
        .filter {
            (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                && NSImage(contentsOf: $0) != nil
        }
    }

    private func orderedUserImageURLs() throws -> [URL] {
        let urls = try imageURLs(in: directoryURL)
        let importOrder = loadImportOrder()
        var orderByFilename: [String: Int] = [:]
        for (index, filename) in importOrder.enumerated() where orderByFilename[filename] == nil {
            orderByFilename[filename] = index
        }

        return urls.sorted { left, right in
            let leftOrder = orderByFilename[left.lastPathComponent]
            let rightOrder = orderByFilename[right.lastPathComponent]
            switch (leftOrder, rightOrder) {
            case let (.some(leftOrder), .some(rightOrder)):
                return leftOrder < rightOrder
            case (.none, .some):
                return true
            case (.some, .none):
                return false
            case (.none, .none):
                return isEarlierLegacyImage(left, than: right)
            }
        }
    }

    private func isEarlierLegacyImage(_ left: URL, than right: URL) -> Bool {
        let keys: Set<URLResourceKey> = [.creationDateKey, .contentModificationDateKey]
        let leftValues = try? left.resourceValues(forKeys: keys)
        let rightValues = try? right.resourceValues(forKeys: keys)
        let leftCreationDate = leftValues?.creationDate ?? .distantPast
        let rightCreationDate = rightValues?.creationDate ?? .distantPast
        if leftCreationDate != rightCreationDate {
            return leftCreationDate < rightCreationDate
        }

        let leftModificationDate = leftValues?.contentModificationDate ?? .distantPast
        let rightModificationDate = rightValues?.contentModificationDate ?? .distantPast
        if leftModificationDate != rightModificationDate {
            return leftModificationDate < rightModificationDate
        }

        return left.lastPathComponent.localizedStandardCompare(right.lastPathComponent) == .orderedAscending
    }

    private func loadImportOrder() -> [String] {
        guard let data = try? Data(contentsOf: importOrderURL) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    private func appendToImportOrder(_ imageName: String) throws {
        var importOrder = loadImportOrder()
        importOrder.removeAll { $0 == imageName }
        importOrder.append(imageName)
        try JSONEncoder().encode(importOrder).write(to: importOrderURL, options: .atomic)
    }

    func importImage(from sourceURL: URL) throws -> String {
        let hasSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard NSImage(contentsOf: sourceURL) != nil else {
            throw StoreError.invalidImage
        }

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let fileExtension = sourceURL.pathExtension.isEmpty
            ? "image"
            : sourceURL.pathExtension.lowercased()
        let imageName = "\(UUID().uuidString).\(fileExtension)"
        let destinationURL = directoryURL.appendingPathComponent(imageName)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        do {
            try appendToImportOrder(imageName)
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            throw error
        }
        return imageName
    }

    func image(named imageName: String?) -> NSImage? {
        guard let imageName = TimedReminderBackgroundImageReference.sanitized(imageName) else {
            return nil
        }
        if let filename = TimedReminderBackgroundImageReference.builtInFilename(from: imageName) {
            guard let builtInDirectoryURL else { return nil }
            return NSImage(contentsOf: builtInDirectoryURL.appendingPathComponent(filename))
        }
        guard let imageURL = url(for: imageName) else { return nil }
        return NSImage(contentsOf: imageURL)
    }

    func removeImage(named imageName: String?) throws {
        guard let imageName = TimedReminderBackgroundImageReference.sanitized(imageName) else { return }
        guard TimedReminderBackgroundImageReference.builtInFilename(from: imageName) == nil else { return }
        guard let imageURL = url(for: imageName) else { return }
        guard FileManager.default.fileExists(atPath: imageURL.path) else { return }
        try FileManager.default.removeItem(at: imageURL)
    }

    private func url(for imageName: String?) -> URL? {
        guard let imageName = TimedReminderBackgroundImageReference.sanitized(imageName),
              TimedReminderBackgroundImageReference.builtInFilename(from: imageName) == nil else { return nil }

        return directoryURL.appendingPathComponent(imageName)
    }
}
