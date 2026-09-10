import AppKit
import SwiftUI

enum TimedReminderPopupLayout {
    static let cardSize = CGSize(width: 420, height: 250)
    static let ambientShadowRadius: CGFloat = 28
    static let ambientShadowOffsetY: CGFloat = 14
    static let shadowPadding: CGFloat = 72
    static let windowSize = CGSize(
        width: cardSize.width + shadowPadding * 2,
        height: cardSize.height + shadowPadding * 2
    )
    static let cornerRadius: CGFloat = 26
}

private enum TimedReminderPopupPalette {
    static let ink = Color(red: 0.25, green: 0.13, blue: 0.035)
    static let secondaryInk = ink.opacity(0.66)
    static let accent = Color(red: 0.72, green: 0.26, blue: 0.025)
    static let topBackground = Color(red: 1.00, green: 0.84, blue: 0.36)
    static let bottomBackground = Color(red: 1.00, green: 0.67, blue: 0.16)
    static let imageContentSurface = Color(red: 1.00, green: 0.91, blue: 0.72)
        .opacity(0.80)
}

@MainActor
final class TimedReminderPopupModel: ObservableObject {
    static let dismissalSeconds = 30

    @Published var text = ""
    @Published var secondsRemaining = dismissalSeconds
    @Published var isPresented = false
    @Published var snoozeDuration = TimedReminderSnoozeDuration.fiveMinutes
    @Published var backgroundImage: NSImage?
    @Published var displayLanguage = AppLanguage.system
    @Published var autoCloseEnabled = true
    @Published var presentationDate = Date()
    var dismiss: () -> Void = {}
    var snooze: (TimedReminderSnoozeDuration) -> Void = { _ in }

    func confirmSnooze() {
        snooze(snoozeDuration)
    }

    func presentationTimeText(timeZone: TimeZone = .autoupdatingCurrent) -> String {
        let formatter = DateFormatter()
        formatter.locale = displayLanguage.locale
        formatter.timeZone = timeZone
        formatter.dateFormat = displayLanguage.resolved == .englishUS
            ? "MMM d, h:mm a"
            : "M月d日 HH:mm"
        return formatter.string(from: presentationDate)
    }
}

struct TimedReminderPopupView: View {
    @ObservedObject var model: TimedReminderPopupModel

    private func localized(_ key: String, _ arguments: CVarArg...) -> String {
        AppLocalization.localized(key, language: model.displayLanguage, arguments: arguments)
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .topTrailing) {
                popupBackground

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        AnimatedReminderBell(isAnimating: model.isPresented, usesImageBackground: usesImageBackground)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(localized("清醒贴"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(usesImageBackground ? .white : TimedReminderPopupPalette.accent)

                            Text(localized("定时提醒"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(usesImageBackground ? .white : TimedReminderPopupPalette.secondaryInk)
                        }
                    }
                    .shadow(color: .black.opacity(usesImageBackground ? 0.25 : 0), radius: 3, y: 1)

                    reminderMessage
                        .padding(.top, 16)

                    Spacer(minLength: 10)

                    HStack(alignment: .center, spacing: 8) {
                        reminderStatus

                        Spacer(minLength: 0)

                        snoozeControl
                            .layoutPriority(1)
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 6)
                    .padding(.vertical, 6)
                    .background(
                        usesImageBackground
                            ? TimedReminderPopupPalette.imageContentSurface
                            : .white.opacity(0.30),
                        in: Capsule()
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 28)
                .padding(.trailing, 26)
                .padding(.top, 24)
                .padding(.bottom, 20)

                Button(action: model.dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 30, height: 30)
                        .background(
                            usesImageBackground
                                ? .clear
                                : .white.opacity(0.28),
                            in: Circle()
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(usesImageBackground ? .white : TimedReminderPopupPalette.secondaryInk)
                .shadow(color: .black.opacity(usesImageBackground ? 0.35 : 0), radius: 3, y: 1)
                .padding(16)
                .help(localized("关闭"))
                .accessibilityLabel(localized("关闭定时提醒"))
            }
            .frame(
                width: TimedReminderPopupLayout.cardSize.width,
                height: TimedReminderPopupLayout.cardSize.height
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: TimedReminderPopupLayout.cornerRadius,
                    style: .continuous
                )
            )
            .shadow(
                color: Color(red: 0.34, green: 0.16, blue: 0.025).opacity(0.18),
                radius: 9,
                x: 0,
                y: 6
            )
            .shadow(
                color: Color(red: 0.34, green: 0.16, blue: 0.025).opacity(0.14),
                radius: TimedReminderPopupLayout.ambientShadowRadius,
                x: 0,
                y: TimedReminderPopupLayout.ambientShadowOffsetY
            )
        }
        .frame(
            width: TimedReminderPopupLayout.windowSize.width,
            height: TimedReminderPopupLayout.windowSize.height
        )
        .appLanguage(model.displayLanguage)
    }

    private var popupBackground: some View {
        ZStack {
            if let backgroundImage = model.backgroundImage {
                Image(nsImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: TimedReminderPopupLayout.cardSize.width,
                        height: TimedReminderPopupLayout.cardSize.height
                    )
                    .clipped()

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.35), location: 0),
                        .init(color: .black.opacity(0.40), location: 0.48),
                        .init(color: .black.opacity(0.25), location: 0.70),
                        .init(color: .black.opacity(0.05), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [
                        TimedReminderPopupPalette.topBackground,
                        TimedReminderPopupPalette.bottomBackground,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(.white.opacity(0.24))
                    .frame(width: 210, height: 210)
                    .blur(radius: 34)
                    .offset(x: 170, y: -112)

                Circle()
                    .fill(Color.orange.opacity(0.20))
                    .frame(width: 180, height: 180)
                    .blur(radius: 42)
                    .offset(x: -175, y: 126)
            }
        }
        .accessibilityHidden(true)
    }

    private var usesImageBackground: Bool {
        model.backgroundImage != nil
    }

    @ViewBuilder
    private var reminderStatus: some View {
        if model.autoCloseEnabled {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(model.secondsRemaining)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(TimedReminderPopupPalette.accent)
                    .contentTransition(.numericText())

                Text(localized("秒后自动关闭"))
                    .font(.system(size: 11))
                    .foregroundStyle(TimedReminderPopupPalette.secondaryInk)
                    .fixedSize()
            }
        } else {
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 13.2, weight: .semibold))

                Text(model.presentationTimeText())
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            .foregroundStyle(TimedReminderPopupPalette.secondaryInk)
            .accessibilityLabel(localized("提醒时间"))
            .accessibilityValue(model.presentationTimeText())
        }
    }

    @ViewBuilder
    private var reminderMessage: some View {
        if usesImageBackground {
            styledReminderText
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                .frame(maxWidth: 356, alignment: .leading)
        } else {
            styledReminderText
                .frame(maxWidth: 332, minHeight: 76, alignment: .leading)
        }
    }

    private var styledReminderText: some View {
        Text(model.text)
            .font(.system(size: 23, weight: .semibold, design: .rounded))
            .tracking(-0.3)
            .foregroundStyle(usesImageBackground ? .white : TimedReminderPopupPalette.ink)
            .multilineTextAlignment(.leading)
            .lineLimit(3)
    }

    private var snoozeControl: some View {
        HStack(spacing: 5) {
            Picker(localized("稍后提醒时长"), selection: $model.snoozeDuration) {
                ForEach(TimedReminderSnoozeDuration.allCases) { duration in
                    Text(duration.title).tag(duration)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(width: 100)
            .tint(TimedReminderPopupPalette.accent)

            Text(localized("分钟后"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TimedReminderPopupPalette.secondaryInk)
                .fixedSize()

            Button(action: model.confirmSnooze) {
                Text(localized("再提醒"))
                    .fixedSize(horizontal: true, vertical: false)
            }
                .buttonStyle(SnoozeConfirmationButtonStyle())
                .accessibilityLabel(localized("确认稍后提醒"))
                .accessibilityValue(localized("%ld 分钟后", model.snoozeDuration.rawValue))
        }
    }
}

private struct SnoozeConfirmationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.96))
            .padding(.horizontal, 10)
            .frame(minWidth: 58, minHeight: 28)
            .background(
                TimedReminderPopupPalette.accent.opacity(configuration.isPressed ? 0.76 : 0.92),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.20), lineWidth: 0.75)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

enum ReminderBellAnimation {
    static let activeDuration: TimeInterval = 0.62
    static let cycleDuration: TimeInterval = 1.18

    static func angle(at elapsedTime: TimeInterval) -> Double {
        let cycleTime = elapsedTime.truncatingRemainder(dividingBy: cycleDuration)
        guard cycleTime >= 0, cycleTime < activeDuration else { return 0 }

        let progress = cycleTime / activeDuration
        let amplitude = 13 * (1 - progress * 0.48)
        return sin(progress * .pi * 9) * amplitude
    }
}

private struct AnimatedReminderBell: View {

    let isAnimating: Bool
    var usesImageBackground = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 30.0,
                paused: reduceMotion || !isAnimating
            )
        ) { timeline in
            let angle = reduceMotion || !isAnimating
                ? 0
                : ReminderBellAnimation.angle(
                    at: timeline.date.timeIntervalSinceReferenceDate
                )

            Image(systemName: "bell.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(usesImageBackground ? .white : TimedReminderPopupPalette.accent)
                .rotationEffect(.degrees(angle), anchor: .top)
            }
        .frame(width: 42, height: 42)
        .background(usesImageBackground ? .clear : .white.opacity(0.32), in: RoundedRectangle(cornerRadius: 13))
    }
}
