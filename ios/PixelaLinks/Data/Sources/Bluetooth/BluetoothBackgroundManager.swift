import CoreBluetooth
import Foundation

final class BluetoothBackgroundManager: NSObject {
    static let shared = BluetoothBackgroundManager()

    private static let restoreKey = "com.pixela.links.bluetooth"
    private var centralManager: CBCentralManager?
    // Written/read on CBCentralManager queue (serial)
    private(set) var connectionCount: Double = 0

    override init() {
        super.init()
        // Initialize early for state restoration
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionRestoreIdentifierKey: Self.restoreKey]
        )
    }

    func start() {
        // Manager is already initialized in init() for state restoration.
        // Actual peripheral scanning is Phase 4.
    }

    func makeDataSource() -> any ActivityDataSource {
        BluetoothDataSource(manager: self)
    }
}

extension BluetoothBackgroundManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {}

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionCount += 1
        Task {
            await BackgroundSyncCoordinator.shared.sync(types: [.bluetoothConnectionCount])
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        willRestoreState dict: [String: Any]
    ) {
        // Peripherals that were connected before app was killed are restored here
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
