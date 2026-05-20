import Combine
import Foundation

extension ImageToolsViewModel {
    /// Observes only the fields that contribute to `ProcessingConfiguration`.
    /// This keeps export, ingestion, cache, and other published state out of the
    /// processing/comparison refresh path.
    func setupConfigurationChangeObservation() {
        lastConfigurationForSideEffects = currentConfiguration

        let settingsChanges: [AnyPublisher<Void, Never>] = [
            $resizeMode.map { _ in () }.eraseToAnyPublisher(),
            $resizeWidth.map { _ in () }.eraseToAnyPublisher(),
            $resizeHeight.map { _ in () }.eraseToAnyPublisher(),
            $resizeLongEdge.map { _ in () }.eraseToAnyPublisher(),
            $selectedFormat.map { _ in () }.eraseToAnyPublisher(),
            $compressionPercent.map { _ in () }.eraseToAnyPublisher(),
            $flipV.map { _ in () }.eraseToAnyPublisher(),
            $removeMetadata.map { _ in () }.eraseToAnyPublisher(),
            $removeBackground.map { _ in () }.eraseToAnyPublisher()
        ]

        Publishers.MergeMany(settingsChanges)
            .dropFirst(settingsChanges.count)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleConfigurationSideEffectsIfNeeded()
            }
            .store(in: &cancellables)
    }

    func scheduleConfigurationSideEffectsIfNeeded() {
        let configuration = currentConfiguration
        guard configuration != lastConfigurationForSideEffects else { return }

        lastConfigurationForSideEffects = configuration
        scheduleProcessing()
        scheduleComparisonPreviewRefresh()
    }
}
