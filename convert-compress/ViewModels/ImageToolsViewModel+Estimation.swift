import Foundation

extension ImageToolsViewModel {
    private func mergeEstimatedBytes(with map: [UUID: Int]) {
        estimatedBytes.merge(map) { _, new in new }
    }

    func triggerEstimationForVisible(_ visibleAssets: [ImageAsset]) {
        // Cancel previous run
        estimationTask?.cancel()
        let config = currentConfiguration

        estimationTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            let map = await TrueSizeEstimator.estimate(
                assets: visibleAssets,
                configuration: config
            )
            self.mergeEstimatedBytes(with: map)
        }
    }
}


