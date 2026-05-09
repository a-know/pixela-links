import CoreBluetooth
import Foundation

final class BluetoothBackgroundManager: NSObject {
    static let shared = BluetoothBackgroundManager()

    private static let restoreKey = "com.pixela.links.bluetooth"
    private var centralManager: CBCentralManager?
    // Written/read on main thread (queue: nil → main queue)
    private(set) var connectionCount: Double = 0
    private var resetDateString = ""

    override init() {
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionRestoreIdentifierKey: Self.restoreKey]
        )
    }

    func start() {}

    func makeDataSource() -> any ActivityDataSource {
        BluetoothDataSource(manager: self)
    }

    private func resetIfDayChanged() {
        let today = DateFormatter.pixelaDate.string(from: .now)
        guard resetDateString != today else { return }
        resetDateString = today
        connectionCount = 0
    }
}

extension BluetoothBackgroundManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {}

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        resetIfDayChanged()
        connectionCount += 1
        Task {
            await BackgroundSyncCoordinator.shared.sync(types: [.bluetoothConnectionCount])
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        willRestoreState dict: [String: Any]
    ) {
        let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
        if !restored.isEmpty {
            Task {
                await BackgroundSyncCoordinator.shared.sync(types: [.bluetoothConnectionCount])
            }
        }
    }
}

struct BluetoothDataSource: ActivityDataSource, @unchecked Sendable {
    let type: ActivityType = .bluetoothConnectionCount
    private let manager: BluetoothBackgroundManager

    fileprivate init(manager: BluetoothBackgroundManager) {
        self.manager = manager
    }

    func requestAuthorization() async throws {}

    func fetchTodayTotal() async throws -> Double {
        manager.connectionCount
    }
}
