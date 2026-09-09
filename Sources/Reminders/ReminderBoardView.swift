import SwiftUI

struct ReminderBoardView: View {
    let configuration: AppConfiguration

    private var layout: ReminderCardLayout {
        ReminderCardLayout(
            fontSize: configuration.reminderFontSize,
            panelWidth: configuration.reminderWidth
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: layout.cardSpacing) {
                ForEach(Array(configuration.visibleItems.enumerated()), id: \.element.id) { index, item in
                    reminderCard(item, number: index + 1)
                }
            }
            .padding(ReminderCardLayout.contentInset)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(configuration.displayLanguage.localized("清醒贴提醒"))
        .appLanguage(configuration.displayLanguage)
    }

    private func reminderCard(_ item: ReminderItem, number: Int) -> some View {
        HStack(alignment: .center, spacing: layout.contentSpacing) {
            Text("\(number)")
                .font(.system(size: layout.numberFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(configuration.backgroundColor.color)
                .frame(width: layout.numberDiameter, height: layout.numberDiameter)
                .background(configuration.textColor.color.opacity(0.88), in: Circle())
                .accessibilityHidden(true)

            Text(
                item.text.isEmpty
                    ? configuration.displayLanguage.localized("未填写提醒")
                    : item.text
            )
                .font(.system(size: configuration.reminderFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(configuration.textColor.color)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, layout.horizontalPadding)
        .padding(.vertical, layout.verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                .fill(configuration.backgroundColor.color)
                .shadow(color: .black.opacity(0.055), radius: 18, y: 9)
                .shadow(color: .black.opacity(0.10), radius: 5, y: 3)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            configuration.displayLanguage.localized("提醒 %ld：%@", number, item.text)
        )
    }
}
