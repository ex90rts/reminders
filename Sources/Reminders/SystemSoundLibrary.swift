import AppKit
import Foundation

struct SystemSoundOption: Identifiable, Hashable {
    let id: String
    let displayName: String

    fileprivate let fileURL: URL
}

enum SystemSoundLibrary {
    private typealias LocalizationTable = [String: [String: String]]

    private static let legacySoundsDirectory = URL(
        fileURLWithPath: "/System/Library/Sounds",
        isDirectory: true
    )
    private static let toneResourcesDirectory = URL(
        fileURLWithPath: "/System/Library/PrivateFrameworks/ToneLibrary.framework/Versions/A/Resources",
        isDirectory: true
    )
    private static let ringtonesDirectory = toneResourcesDirectory
        .appendingPathComponent("Ringtones", isDirectory: true)

    // Matches the order used by the current macOS alarm sound picker.
    private static let currentAlarmTones: [(id: String, localizationName: String)] = [
        ("Radial-EncoreInfinitum", "Radial"),
        ("Shelter-EncoreInfinitum", "Shelter"),
        ("Departure-EncoreInfinitum", "Departure"),
        ("Reflection-EncoreInfinitum", "Reflection"),
        ("Canopy-EncoreInfinitum", "Canopy"),
        ("Storytime-EncoreInfinitum", "Storytime"),
        ("Steps-EncoreInfinitum", "Steps"),
        ("Daybreak-EncoreInfinitum", "Daybreak"),
        ("Journey-EncoreInfinitum", "Journey"),
        ("Arpeggio-EncoreInfinitum", "Arpeggio"),
        ("Tilt-EncoreInfinitum", "Tilt"),
        ("Valley-EncoreInfinitum", "Valley"),
        ("Kettle-EncoreInfinitum", "Kettle"),
        ("Mercury-EncoreInfinitum", "Mercury"),
        ("Quad-EncoreInfinitum", "Quad"),
        ("Sprinkles-EncoreInfinitum", "Sprinkles"),
        ("Dollop-EncoreInfinitum", "Dollop"),
        ("Tease-EncoreInfinitum", "Tease"),
        ("Chalet-EncoreInfinitum", "Chalet"),
        ("Scavenger-EncoreInfinitum", "Scavenger"),
        ("Milky Way-EncoreInfinitum", "Milky Way"),
        ("Seedling-EncoreInfinitum", "Seedling"),
        ("Unfold-EncoreInfinitum", "Unfold"),
        ("Chirp-EncoreInfinitum", "Chirp"),
        ("Breaking-EncoreInfinitum", "Breaking"),
    ]

    private static let standardLocalizations = loadLocalizationTable(named: "TL")
    private static let currentToneLocalizations = loadLocalizationTable(named: "TL-EncoreInfinitum")

    static let availableSounds: [SystemSoundOption] = {
        let currentSounds = currentAlarmTones.compactMap { descriptor -> SystemSoundOption? in
            let fileURL = ringtonesDirectory
                .appendingPathComponent(descriptor.id)
                .appendingPathExtension("m4r")
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

            return SystemSoundOption(
                id: descriptor.id,
                displayName: localizedDisplayName(for: descriptor.localizationName),
                fileURL: fileURL
            )
        }

        if currentSounds.count == currentAlarmTones.count {
            return currentSounds
        }

        let systemRingtones = loadSystemRingtones()
        return systemRingtones.isEmpty ? loadLegacySounds() : systemRingtones
    }()

    static var availableNames: [String] {
        availableSounds.map(\.id)
    }

    static func displayName(for name: String) -> String {
        availableSounds.first(where: { $0.id == name })?.displayName ?? name
    }

    static func sound(named name: String?) -> NSSound? {
        guard let name, !name.isEmpty else { return nil }

        if let option = availableSounds.first(where: { $0.id == name }) {
            return NSSound(contentsOf: option.fileURL, byReference: true)
        }

        let ringtoneURL = ringtonesDirectory
            .appendingPathComponent(name)
            .appendingPathExtension("m4r")
        if FileManager.default.fileExists(atPath: ringtoneURL.path),
           let sound = NSSound(contentsOf: ringtoneURL, byReference: true) {
            return sound
        }

        return NSSound(named: NSSound.Name(name))
    }

    private static func loadSystemRingtones() -> [SystemSoundOption] {
        loadAudioFiles(in: ringtonesDirectory).map { fileURL in
            let identifier = fileURL.deletingPathExtension().lastPathComponent
            return SystemSoundOption(
                id: identifier,
                displayName: localizedDisplayName(
                    for: localizationName(from: identifier)
                ),
                fileURL: fileURL
            )
        }
        .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private static func loadLegacySounds() -> [SystemSoundOption] {
        loadAudioFiles(in: legacySoundsDirectory).map { fileURL in
            let name = fileURL.deletingPathExtension().lastPathComponent
            return SystemSoundOption(id: name, displayName: name, fileURL: fileURL)
        }
        .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private static func loadAudioFiles(in directory: URL) -> [URL] {
        let supportedExtensions = Set(["aiff", "caf", "m4a", "m4r", "wav"])
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls.filter {
            supportedExtensions.contains($0.pathExtension.lowercased())
        }
    }

    private static func localizationName(from identifier: String) -> String {
        identifier
            .replacingOccurrences(of: "-EncoreInfinitum", with: "")
            .replacingOccurrences(of: "-EncoreRemix", with: "")
    }

    private static func localizedDisplayName(for localizationName: String) -> String {
        if localizationName == "Reflection" {
            return localizedValue(
                forKey: "RINGTONE_PICKER_DEFAULT_MODERN_RINGTONE_NAME",
                in: standardLocalizations
            ) ?? localizationName
        }

        let key = "system:\(localizationName)"
        return localizedValue(forKey: key, in: currentToneLocalizations)
            ?? localizedValue(forKey: key, in: standardLocalizations)
            ?? localizationName
    }

    private static func loadLocalizationTable(named name: String) -> LocalizationTable {
        let fileURL = toneResourcesDirectory
            .appendingPathComponent(name)
            .appendingPathExtension("loctable")
        var format = PropertyListSerialization.PropertyListFormat.binary
        guard let data = try? Data(contentsOf: fileURL),
              let propertyList = try? PropertyListSerialization.propertyList(
                  from: data,
                  options: [],
                  format: &format
              ),
              let rawTable = propertyList as? [String: Any] else {
            return [:]
        }

        return rawTable.reduce(into: LocalizationTable()) { table, entry in
            guard let localizedValues = entry.value as? [String: String] else { return }
            table[entry.key] = localizedValues
        }
    }

    private static func localizedValue(
        forKey key: String,
        in table: LocalizationTable
    ) -> String? {
        let availableLocalizations = Array(table.keys)
        let preferredLocalization = Bundle.preferredLocalizations(
            from: availableLocalizations,
            forPreferences: Locale.preferredLanguages
        ).first

        if let preferredLocalization,
           let value = table[preferredLocalization]?[key] {
            return value
        }
        return table["en"]?[key]
    }
}
