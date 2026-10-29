import SwiftUI

struct BatteryAlertCard: View {
    let alert: BatteryAlert
    let percentage: Int?
    let conditionText: String
    var body: some View {
        Label(alert.message, systemImage: alert.symbolName)
            .font(.system(size: 11, weight: .medium)).foregroundStyle(SelaTheme.amber)
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(SelaTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
    }
}
struct BatteryAlertBanner: View {
    @ObservedObject var battery: BatteryModel
    var body: some View {
        if let alert = battery.alert {
            BatteryAlertCard(alert: alert, percentage: battery.percentage, conditionText: battery.conditionText)
        }
    }
}

struct BatteryPanel: View {
    @ObservedObject var battery: BatteryModel
    var body: some View {
        BatteryFace(percentage: battery.percentage, condition: battery.conditionText,
                    charging: battery.condition == .charging,
                    low: battery.condition == .onBattery && (battery.percentage ?? 100) <= BatteryAlertPolicy.lowBatteryThreshold,
                    alertsEnabled: $battery.alertsEnabled, refresh: battery.refresh)
    }
}

struct BatteryFace: View {
    let percentage: Int?
    let condition: String
    var charging = false
    var low = false
    @Binding var alertsEnabled: Bool
    var refresh: () -> Void
    private var tint: Color { low ? SelaTheme.amber : SelaTheme.green }
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text(percentage.map { "\($0)%" } ?? "—")
                    .font(.system(size: 34, weight: .medium)).tracking(-1).monospacedDigit()
                VStack(alignment: .leading, spacing: 4) {
                    Label(charging ? "Mengisi daya" : (low ? "Baterai rendah" : "Daya Mac"), systemImage: charging ? "bolt.fill" : "battery.100")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(tint)
                    Text(condition).font(.system(size: 11)).selaSecondary().lineLimit(2)
                }
                Spacer(minLength: 0)
                SelaIconButton(symbol: "arrow.clockwise", label: "Perbarui baterai", action: refresh)
            }
            SelaProgress(progress: Double(percentage ?? 0) / 100, tint: tint)
            HStack {
                Toggle("Battery Alerts", isOn: $alertsEnabled).toggleStyle(.switch).controlSize(.mini)
                    .font(.system(size: 11)).accessibilityLabel("Pemberitahuan charger dan baterai rendah")
                Spacer()
                Text("Ambang \(BatteryAlertPolicy.lowBatteryThreshold)%").font(.system(size: 11)).selaSecondary()
            }
        }.frame(height: 116).foregroundStyle(SelaTheme.ivory)
    }
}
#Preview("Battery · Charging") {
    BatteryFace(percentage: 76, condition: "Sedang mengisi daya", charging: true, alertsEnabled: .constant(true), refresh: {})
        .padding(16).frame(width: 408).selaSurface()
}
#Preview("Battery · Low") {
    BatteryFace(percentage: 14, condition: "Hubungkan charger", low: true, alertsEnabled: .constant(true), refresh: {})
        .padding(16).frame(width: 408).selaSurface()
}
