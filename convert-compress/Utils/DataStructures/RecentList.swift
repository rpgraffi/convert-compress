import Foundation

struct RecentList<Element: Hashable> {
    private(set) var elements: [Element]
    let maxCount: Int

    init(_ elements: [Element] = [], maxCount: Int) {
        self.maxCount = maxCount
        self.elements = Array(elements.prefix(maxCount))
    }

    mutating func insert(_ element: Element) {
        elements.removeAll { $0 == element }
        elements.insert(element, at: 0)
        if elements.count > maxCount {
            elements = Array(elements.prefix(maxCount))
        }
    }
}
