import Foundation

/// Bounded export parallelism for full-resolution image pipelines.
enum ExportConcurrencyPolicy {
    static func recommended(processInfo: ProcessInfo = .processInfo) -> Int {
        recommended(
            activeProcessorCount: processInfo.activeProcessorCount,
            physicalMemory: processInfo.physicalMemory,
            isLowPowerModeEnabled: processInfo.isLowPowerModeEnabled,
            thermalState: processInfo.thermalState
        )
    }

    static func recommended(
        activeProcessorCount: Int,
        physicalMemory: UInt64,
        isLowPowerModeEnabled: Bool,
        thermalState: ProcessInfo.ThermalState
    ) -> Int {
        let memoryGB = gibibytes(physicalMemory)
        let steadyStateLimit = min(
            cpuLimit(activeProcessorCount: activeProcessorCount),
            memoryLimit(physicalMemoryGB: memoryGB)
        )

        var adjustedLimit = min(steadyStateLimit, thermalLimit(thermalState))
        if isLowPowerModeEnabled {
            adjustedLimit = min(adjustedLimit, lowPowerModeLimit)
        }

        return clamp(adjustedLimit)
    }

    // MARK: - Private

    private static let minimumLimit = 1
    private static let maximumLimit = 12
    private static let lowPowerModeLimit = 4

    private static let perExportWorkingSetGB = 2.0
    private static let minimumSystemReserveGB = 3.0
    private static let maximumSystemReserveGB = 8.0
    private static let systemReserveFraction = 0.25

    private static func gibibytes(_ bytes: UInt64) -> Double {
        Double(bytes) / (1_024.0 * 1_024.0 * 1_024.0)
    }

    /// Leave CPU capacity for the UI, file I/O, and system services.
    private static func cpuLimit(activeProcessorCount: Int) -> Int {
        let activeCores = max(1, activeProcessorCount)
        let reservedCores = systemReservedCores(for: activeCores)
        return clamp(activeCores - reservedCores)
    }

    private static func systemReservedCores(for activeCores: Int) -> Int {
        switch activeCores {
        case ...2:
            return 1
        case ...6:
            return 1
        default:
            return max(2, activeCores / 4)
        }
    }

    /// Each in-flight export may retain decoded image data, rendered RGBA pixels, and encoded output.
    private static func memoryLimit(physicalMemoryGB: Double) -> Int {
        let reserveGB = min(
            max(physicalMemoryGB * systemReserveFraction, minimumSystemReserveGB),
            maximumSystemReserveGB
        )
        let exportBudgetGB = max(0, physicalMemoryGB - reserveGB)
        return clamp(Int(exportBudgetGB / perExportWorkingSetGB))
    }

    private static func thermalLimit(_ state: ProcessInfo.ThermalState) -> Int {
        switch state {
        case .nominal:
            return maximumLimit
        case .fair:
            return 6
        case .serious:
            return 2
        case .critical:
            return 1
        @unknown default:
            return 2
        }
    }

    private static func clamp(_ value: Int) -> Int {
        max(minimumLimit, min(value, maximumLimit))
    }
}
