import AppKit

final class LocalEventMonitor {
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent) -> NSEvent?
    private var monitor: Any?

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> NSEvent?) {
        self.mask = mask
        self.handler = handler
    }

    func start() {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: handler)
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    deinit {
        stop()
    }
}

