import SwiftUI

struct BatteryAlertCard: View {
    let alert: BatteryAlert
    let percentage: Int?
    let conditionText: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: alert.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.message)
                    .font(.caption.weight(.semibold))

                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    private var detail: String? {
        if case .lowBattery = alert { return nil }
        guard let percentage else { return conditionText }
        return "\(percentage)% · \(conditionText)"
    }

    private var tint: Color {
        switch alert {
        case .chargerConnected: return .green
        case .chargerDisconnected: return .secondary
        case .lowBattery: return .orange
        }
    }
}

struct BatteryAlertBanner: View {
    @ObservedObject var battery: BatteryModel

    var body: some View {
        Group {
            if let alert = battery.alert {
                BatteryAlertCard(
                    alert: alert,
                    percentage: battery.percentage,
                    conditionText: battery.conditionText
                )
                .frame(width: 272)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: battery.alert)
    }
}

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
