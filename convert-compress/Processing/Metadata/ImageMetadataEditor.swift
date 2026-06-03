import Foundation
import UniformTypeIdentifiers

enum ImageMetadataField: Hashable {
    case title
    case creator
    case publisher
    case description
    case creatorTool

    fileprivate var xmpName: XMPElementName {
        switch self {
        case .title:
            XMPElementName(prefix: "dc", localName: "title", namespaceURI: "http://purl.org/dc/elements/1.1/")
        case .creator:
            XMPElementName(prefix: "dc", localName: "creator", namespaceURI: "http://purl.org/dc/elements/1.1/")
        case .publisher:
            XMPElementName(prefix: "dc", localName: "publisher", namespaceURI: "http://purl.org/dc/elements/1.1/")
        case .description:
            XMPElementName(prefix: "dc", localName: "description", namespaceURI: "http://purl.org/dc/elements/1.1/")
        case .creatorTool:
            XMPElementName(prefix: "xmp", localName: "CreatorTool", namespaceURI: "http://ns.adobe.com/xap/1.0/")
        }
    }
}

enum ImageMetadataFieldAction: Equatable {
    case set(String)
    case remove
}

struct ImageMetadataEditPlan: Equatable {
    let actions: [ImageMetadataField: ImageMetadataFieldAction]

    var isEmpty: Bool {
        actions.isEmpty
    }

    init(_ actions: [ImageMetadataField: ImageMetadataFieldAction]) {
        self.actions = actions
    }

    static let appAuthorship = ImageMetadataEditPlan([
        .title: .remove,
        .creator: .set(AppConstants.localizedAppName),
        .publisher: .remove,
        .description: .remove,
        .creatorTool: .set(AppConstants.localizedAppName)
    ])
}

enum ImageMetadataEditingError: Error {
    case invalidXMPPacket
    case metadataPacketCannotGrow
}

struct ImageMetadataEditor {
    static func apply(_ plan: ImageMetadataEditPlan, to data: Data, utType: UTType) throws -> Data {
        guard !plan.isEmpty else {
            return data
        }

        if utType == .avif {
            return try XMPPacketEditor.apply(plan, to: data)
        }

        return data
    }
}

private struct XMPElementName {
    let prefix: String
    let localName: String
    let namespaceURI: String

    var qualifiedName: String {
        "\(prefix):\(localName)"
    }
}

private struct XMPPacketParts {
    let prefix: String
    let body: String
    let suffix: String
}

private enum XMPPacketEditor {
    static func apply(_ plan: ImageMetadataEditPlan, to data: Data) throws -> Data {
        guard let range = packetRange(in: data) else {
            return data
        }

        let originalPacketData = Data(data[range])
        guard let originalPacket = String(data: originalPacketData, encoding: .utf8) else {
            throw ImageMetadataEditingError.invalidXMPPacket
        }

        let updatedPacket = try updatePacket(originalPacket, with: plan)
        guard let paddedPacket = paddedPacketData(updatedPacket, originalByteCount: originalPacketData.count) else {
            throw ImageMetadataEditingError.metadataPacketCannotGrow
        }

        var output = data
        output.replaceSubrange(range, with: paddedPacket)
        return output
    }

    private static func packetRange(in data: Data) -> Range<Data.Index>? {
        let rootStartMarker = Data("<x:xmpmeta".utf8)
        let rootEndMarker = Data("</x:xmpmeta>".utf8)
        let packetBeginMarker = Data("<?xpacket begin=".utf8)
        let packetEndMarker = Data("<?xpacket end=".utf8)
        let processingInstructionCloseMarker = Data("?>".utf8)

        guard let rootStart = data.range(of: rootStartMarker)?.lowerBound,
              let rootEndRange = data.range(of: rootEndMarker, options: [], in: rootStart..<data.endIndex) else {
            return nil
        }

        let packetStart = data.range(
            of: packetBeginMarker,
            options: [],
            in: data.startIndex..<rootStart
        )?.lowerBound ?? rootStart

        let packetEnd: Data.Index
        if let endMarkerRange = data.range(of: packetEndMarker, options: [], in: rootEndRange.upperBound..<data.endIndex),
           let closeRange = data.range(
            of: processingInstructionCloseMarker,
            options: [],
            in: endMarkerRange.upperBound..<data.endIndex
           ) {
            packetEnd = closeRange.upperBound
        } else {
            packetEnd = rootEndRange.upperBound
        }

        return packetStart..<packetEnd
    }

    private static func updatePacket(_ packet: String, with plan: ImageMetadataEditPlan) throws -> String {
        let parts = try split(packet)
        let document = try XMLDocument(xmlString: parts.body, options: [.nodePreserveWhitespace])

        for (field, action) in plan.actions {
            try apply(action, to: field, in: document)
        }

        guard let root = document.rootElement() else {
            throw ImageMetadataEditingError.invalidXMPPacket
        }

        return parts.prefix + root.xmlString + parts.suffix
    }

    private static func split(_ packet: String) throws -> XMPPacketParts {
        guard let bodyStart = packet.range(of: "<x:xmpmeta"),
              let bodyEnd = packet.range(of: "</x:xmpmeta>", range: bodyStart.lowerBound..<packet.endIndex) else {
            throw ImageMetadataEditingError.invalidXMPPacket
        }

        let bodyUpperBound = bodyEnd.upperBound
        return XMPPacketParts(
            prefix: String(packet[..<bodyStart.lowerBound]),
            body: String(packet[bodyStart.lowerBound..<bodyUpperBound]),
            suffix: String(packet[bodyUpperBound...])
        )
    }

    private static func apply(_ action: ImageMetadataFieldAction, to field: ImageMetadataField, in document: XMLDocument) throws {
        let name = field.xmpName
        let matchingElements = elements(matching: name, in: document)

        switch action {
        case .set(let value):
            if matchingElements.isEmpty {
                try addElement(named: name, value: value, to: document)
            } else {
                matchingElements.forEach { $0.setStringValue(value, resolvingEntities: false) }
            }
        case .remove:
            matchingElements.forEach { $0.detach() }
        }
    }

    private static func elements(matching name: XMPElementName, in node: XMLNode) -> [XMLElement] {
        var matches: [XMLElement] = []

        if let element = node as? XMLElement,
           elementMatches(element, name: name) {
            matches.append(element)
        }

        for child in node.children ?? [] {
            matches.append(contentsOf: elements(matching: name, in: child))
        }

        return matches
    }

    private static func elementMatches(_ element: XMLElement, name: XMPElementName) -> Bool {
        if element.localName == name.localName,
           element.uri == name.namespaceURI || element.name == name.qualifiedName {
            return true
        }

        return element.name == name.qualifiedName
    }

    private static func addElement(named name: XMPElementName, value: String, to document: XMLDocument) throws {
        guard let description = try descriptionElement(for: name, in: document) else {
            throw ImageMetadataEditingError.invalidXMPPacket
        }

        if description.namespaces?.contains(where: { $0.name == name.prefix && $0.stringValue == name.namespaceURI }) != true {
            guard let namespace = XMLNode.namespace(withName: name.prefix, stringValue: name.namespaceURI) as? XMLNode else {
                throw ImageMetadataEditingError.invalidXMPPacket
            }
            description.addNamespace(namespace)
        }

        description.addChild(XMLElement(name: name.qualifiedName, stringValue: value))
    }

    private static func descriptionElement(for name: XMPElementName, in document: XMLDocument) throws -> XMLElement? {
        let descriptions = elements(
            matching: XMPElementName(prefix: "rdf", localName: "Description", namespaceURI: "http://www.w3.org/1999/02/22-rdf-syntax-ns#"),
            in: document
        )

        if let description = descriptions.first(where: { description in
            description.namespaces?.contains(where: { $0.name == name.prefix && $0.stringValue == name.namespaceURI }) == true
        }) {
            return description
        }

        if let description = descriptions.first {
            return description
        }

        guard let rdf = elements(
            matching: XMPElementName(prefix: "rdf", localName: "RDF", namespaceURI: "http://www.w3.org/1999/02/22-rdf-syntax-ns#"),
            in: document
        ).first else {
            return nil
        }

        let description = XMLElement(name: "rdf:Description")
        guard let namespace = XMLNode.namespace(withName: "rdf", stringValue: "http://www.w3.org/1999/02/22-rdf-syntax-ns#") as? XMLNode else {
            throw ImageMetadataEditingError.invalidXMPPacket
        }
        description.addNamespace(namespace)
        rdf.addChild(description)
        return description
    }

    private static func paddedPacketData(_ packet: String, originalByteCount: Int) -> Data? {
        let packetData = Data(packet.utf8)
        guard packetData.count <= originalByteCount else {
            return nil
        }

        guard packetData.count < originalByteCount else {
            return packetData
        }

        guard let endPacketRange = packet.range(of: "<?xpacket end=", options: .backwards) else {
            return packetData + Data(repeating: UInt8(ascii: " "), count: originalByteCount - packetData.count)
        }

        let paddingByteCount = originalByteCount - packetData.count
        let paddedPacket = packet[..<endPacketRange.lowerBound]
            + String(repeating: " ", count: paddingByteCount)
            + packet[endPacketRange.lowerBound...]
        return Data(paddedPacket.utf8)
    }
}
