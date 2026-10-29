import Foundation

@main
struct BatteryAlertPolicyTests {
    static func main() {
        var failures = 0

        func expect(_ condition: Bool, _ message: String) {
            if !condition {
                failures += 1
                print("FAIL: \(message)")
            }
        }

        var lowAtLaunch = BatteryAlertPolicy()
        expect(
            lowAtLaunch.evaluate(percentage: 20, externalPower: false) == .lowBattery(percentage: 20),
            "baterai 20% saat aplikasi dibuka memberi peringatan satu kali"
        )
        expect(
            lowAtLaunch.evaluate(percentage: 19, externalPower: false) == nil,
            "persentase turun selama rendah tidak mengulang peringatan"
        )
        expect(
            lowAtLaunch.evaluate(percentage: 21, externalPower: false) == nil,
            "baterai pulih di atas 20% tidak memunculkan peringatan"
        )
        expect(
            lowAtLaunch.evaluate(percentage: 20, externalPower: false) == .lowBattery(percentage: 20),
            "peringatan muncul lagi setelah pulih lalu turun ke batas"
        )

        var healthy = BatteryAlertPolicy()
        expect(
            healthy.evaluate(percentage: 21, externalPower: false) == nil,
            "baterai di atas batas tidak memberi peringatan"
        )

        var charger = BatteryAlertPolicy()
        _ = charger.evaluate(percentage: 80, externalPower: false)
        expect(
            charger.evaluate(percentage: 80, externalPower: true) == .chargerConnected,
            "memasang charger memberi pemberitahuan"
        )
        expect(
            charger.evaluate(percentage: 80, externalPower: true) == nil,
            "kondisi charger yang sama tidak mengulang pemberitahuan"
        )
        expect(
            charger.evaluate(percentage: 80, externalPower: false) == .chargerDisconnected,
            "melepas charger memberi pemberitahuan"
        )
        expect(
            charger.evaluate(percentage: 80, externalPower: false) == nil,
            "kondisi tanpa charger yang sama tidak mengulang pemberitahuan"
        )

        var launchedCharging = BatteryAlertPolicy()
        expect(
            launchedCharging.evaluate(percentage: 60, externalPower: true) == nil,
            "aplikasi dibuka saat charger terpasang tidak memunculkan pemberitahuan charger"
        )

        var lowWhilePlugged = BatteryAlertPolicy()
        expect(
            lowWhilePlugged.evaluate(percentage: 10, externalPower: false) == .lowBattery(percentage: 10),
            "baterai rendah saat menggunakan baterai memberi peringatan"
        )
        expect(
            lowWhilePlugged.evaluate(percentage: 10, externalPower: true) == .chargerConnected,
            "memasang charger saat baterai rendah memberi pemberitahuan charger"
        )
        expect(
            lowWhilePlugged.evaluate(percentage: 10, externalPower: false) == .chargerDisconnected,
            "melepas charger saat baterai rendah memberi pemberitahuan charger"
        )
        expect(
            lowWhilePlugged.evaluate(percentage: 10, externalPower: false) == nil,
            "baterai rendah yang sudah diberitahukan tidak diulang"
        )

        var noPercentage = BatteryAlertPolicy()
        expect(
            noPercentage.evaluate(percentage: nil, externalPower: false) == nil,
            "informasi persentase yang belum tersedia tidak memunculkan peringatan"
        )
        expect(
            noPercentage.evaluate(percentage: nil, externalPower: true) == .chargerConnected,
            "perubahan charger tetap terdeteksi tanpa persentase"
        )

        if failures == 0 {
            print("Battery alert policy tests passed.")
        } else {
            print("\(failures) battery alert policy test(s) failed.")
        }
        exit(failures == 0 ? 0 : 1)
    }
}
