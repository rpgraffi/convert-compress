import Foundation
import UniformTypeIdentifiers
import XCTest
@testable import convert_compress

final class ExportRenameTests: XCTestCase {
    @MainActor
    func testRenameModuleCoordinatesTemplateInsertionAndPresentation() {
        clearRenameDefaults()
        defer { clearRenameDefaults() }
        let modules = ImageToolsModules()
        let rename = modules.rename

        rename.setEnabled(true)
        let nextOffset = rename.insert(RenameToken.originalName.text, atUTF16Offset: 0)
        rename.setTemplate("bad/name:\n")
        rename.setEnabled(false)

        XCTAssertEqual(nextOffset, 2)
        XCTAssertEqual(rename.template, "bad_name__")
        XCTAssertFalse(rename.isEnabled)
        XCTAssertFalse(rename.isPopoverPresented)
    }

    @MainActor
    func testRenameModulePlansPreviewAndDuplicateDestinations() {
        clearRenameDefaults()
        defer { clearRenameDefaults() }
        let modules = ImageToolsModules()
        modules.rename.setEnabled(true)
        modules.rename.setTemplate("same")
        modules.assets.images = [
            ImageAsset(url: URL(fileURLWithPath: "/tmp/first.png")),
            ImageAsset(url: URL(fileURLWithPath: "/tmp/second.png"))
        ]

        XCTAssertEqual(modules.rename.previewFilename(for: modules.assets.images[0], index: 0), "same.png")
        XCTAssertTrue(modules.rename.hasDuplicateDestinations)
    }

    func testTokenParserRecognizesKnownTokensOnly() {
        let matches = RenameTokenParser.matches(in: "$&-$today-$created-$modified-$nn-$NNN-$w-$h-$q-$unknown")

        XCTAssertEqual(
            matches.map(\.token),
            [
                .originalName,
                .today,
                .created,
                .modified,
                .indexUp(width: 2),
                .indexDown(width: 3),
                .width,
                .height,
                .quality
            ]
        )
    }

    func testSanitizerReplacesInvalidCharactersAndCapsTemplate() {
        let longName = String(repeating: "a", count: FilenameSanitizer.templateMaxLength + 10)
        let sanitized = FilenameSanitizer.sanitizeTemplateInput("bad/name:\n" + longName)

        XCTAssertTrue(sanitized.hasPrefix("bad_name__"))
        XCTAssertEqual(sanitized.count, FilenameSanitizer.templateMaxLength)
    }

    func testFilenameBuilderExpandsTokens() {
        let asset = ImageAsset(url: URL(fileURLWithPath: "/tmp/photo.png"))
        let settings = ExportRenameSettings(
            isEnabled: true,
            template: "$&_$today_$created_$modified_$nn_$NN_$w_$h_$q",
            dateFormatPreset: .dayMonthYearDots
        )
        let context = ExportFilenameContext(
            asset: asset,
            index: 2,
            totalCount: 5,
            configuration: configuration(compressionPercent: 0.8),
            outputUTType: UTType.jpeg,
            outputSize: CGSize(width: 1024, height: 768),
            today: date(year: 2026, month: 1, day: 2),
            created: date(year: 2026, month: 1, day: 3),
            modified: date(year: 2026, month: 1, day: 4)
        )

        let basename = ExportFilenameBuilder(settings: settings)
            .basename(for: context, filenameExtension: "jpg")

        XCTAssertEqual(basename, "photo_02.01.2026_03.01.2026_04.01.2026_02_02_1024_768_80")
    }

    func testEmptyTemplateFallsBackToOriginalStem() {
        let asset = ImageAsset(url: URL(fileURLWithPath: "/tmp/source:file.png"))
        let settings = ExportRenameSettings(isEnabled: true, template: "", dateFormatPreset: .dayMonthYearDots)
        let context = ExportFilenameContext(
            asset: asset,
            index: 0,
            totalCount: 1,
            configuration: configuration(),
            outputUTType: UTType.png,
            outputSize: nil,
            today: date(year: 2026, month: 1, day: 2),
            created: nil,
            modified: nil
        )

        let basename = ExportFilenameBuilder(settings: settings)
            .basename(for: context, filenameExtension: "png")

        XCTAssertEqual(basename, "source_file")
    }

    func testResolverCanPlanDuplicateDestinations() {
        let resolver = ExportDestinationResolver(
            exportDirectory: URL(fileURLWithPath: "/tmp/export"),
            folderStructureRoot: nil,
            renameSettings: ExportRenameSettings(
                isEnabled: true,
                template: "same",
                dateFormatPreset: .dayMonthYearDots
            ),
            today: date(year: 2026, month: 1, day: 2)
        )
        let config = configuration()
        let first = ImageAsset(url: URL(fileURLWithPath: "/tmp/first.png"))
        let second = ImageAsset(url: URL(fileURLWithPath: "/tmp/second.png"))

        let firstURL = resolver.destinationURL(
            for: ExportDestinationRequest(
                asset: first,
                index: 0,
                totalCount: 2,
                configuration: config,
                outputUTType: UTType.png
            )
        )
        let secondURL = resolver.destinationURL(
            for: ExportDestinationRequest(
                asset: second,
                index: 1,
                totalCount: 2,
                configuration: config,
                outputUTType: UTType.png
            )
        )

        XCTAssertEqual(firstURL, secondURL)
        XCTAssertEqual(firstURL.lastPathComponent, "same.png")
    }

    private func configuration(compressionPercent: Double = 0.8) -> ProcessingConfiguration {
        ProcessingConfiguration(
            resizeMode: .resize,
            resizeWidth: "",
            resizeHeight: "",
            resizeLongEdge: "",
            selectedFormat: nil,
            compressionPercent: compressionPercent,
            flipV: false,
            removeMetadata: false,
            removeBackground: false
        )
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        return components.date!
    }

    private func clearRenameDefaults() {
        UserDefaults.standard.removeObject(forKey: StorageKeys.ExportRename.template)
        UserDefaults.standard.removeObject(forKey: StorageKeys.ExportRename.dateFormatPreset)
    }
}

