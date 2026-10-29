import SwiftUI

struct BatteryPanel: View {
    @ObservedObject var battery: BatteryModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: symbolName)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(battery.percentage.map { "\($0)%" } ?? "—")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .monospacedDigit()

                    Text(battery.conditionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button {
                    battery.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Perbarui status baterai")
            }
            .accessibilityElement(children: .combine)

            Divider()

            Toggle("Battery Alerts", isOn: $battery.alertsEnabled)
                .font(.caption)

            Text("Mengatur pemberitahuan charger dan peringatan baterai rendah.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let alert = battery.alert {
                Label(alert.message, systemImage: alert.symbolName)
                    .font(.caption.weight(.medium))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.yellow.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel(alert.message)
            }
        }
        .padding(12)
        .frame(width: 272)
    }

    private var symbolName: String {
        guard battery.hasBattery else { return "battery.0" }
        if battery.condition == .charging { return "battery.100.bolt" }

        switch battery.percentage ?? 0 {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }

    private var tint: Color {
        if battery.condition == .charging { return .green }
        if battery.condition == .onBattery, let percentage = battery.percentage,
           percentage <= BatteryAlertPolicy.lowBatteryThreshold {
            return .red
        }
        return .primary
    }
}

#Preview {
    BatteryPanel(battery: BatteryModel())
}
