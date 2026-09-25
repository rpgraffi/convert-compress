# Convert & Compress

![Convert & Compress hero banner](.github/assets/github_banner.avif)

[![Download on the App Store](https://img.shields.io/badge/Download-App%20Store-0D96F6?logo=appstore&logoColor=white)](https://apps.apple.com/us/app/convert-compress-images/id6752861983)
[![Swift](https://img.shields.io/badge/Swift-6.2-orange?logo=swift&logoColor=white)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14.6%2B-black?logo=apple&logoColor=white)](https://www.apple.com/macos/)

Convert & Compress is a native macOS image utility for converting, resizing, cropping, and compressing images locally.

The app is built with SwiftUI and a Core Image based processing pipeline. It supports batch workflows, broad image format coverage, metadata control, presets, and private offline processing.

## Features

- Batch convert images with drag-and-drop, paste, and folder workflows.
- Convert across 50+ input formats and 20+ output formats, including JPEG, PNG, HEIC, WebP, AVIF (export on macOS 26+), TIFF, SVG, RAW, ICNS, ICO, and PDF.
- Resize or crop images, including format-aware size constraints for icon formats.
- Adjust compression quality where supported by the target format.
- Preserve or remove privacy-sensitive metadata.
- Save reusable presets that sync through iCloud.
- Process images locally without uploading them to a server.

## Requirements

- macOS 14.6 or later
- Xcode 26 or later
- Swift 6.2 toolchain

## Install From Source

Clone the repository:

```sh
git clone https://github.com/rpgraffi/convert-compress.git
cd convert-compress
```

Open the Xcode project:

```sh
open convert-compress.xcodeproj
```

Then select the `convert-compress` scheme and run the app. Xcode will resolve Swift Package dependencies automatically.

## Build And Test

Build from the command line:

```sh
xcodebuild \
  -project convert-compress.xcodeproj \
  -scheme convert-compress \
  -configuration Debug \
  build
```

Run tests:

```sh
xcodebuild test \
  -project convert-compress.xcodeproj \
  -scheme convert-compress \
  -destination 'platform=macOS'
```


## Links

- [Website](https://convert-compress.com)
- [App Store](https://apps.apple.com/us/app/convert-compress-images/id6752861983)

## Contributing

Issues and focused pull requests are welcome. Please keep changes scoped, follow the existing SwiftUI and processing patterns, and include tests when changing shared behavior.

## License

See [LICENSE](LICENSE).
