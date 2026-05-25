# Decompress

A native macOS decompression tool built with SwiftUI — no ads, no subscriptions, just drag-and-drop extraction.

## Features

- **Drag & drop** or file picker to select archives
- **Auto-detect format** by file extension and magic bytes
- **Extract to source directory** or custom location
- **Progress tracking** during extraction
- **Multiple formats**: ZIP, TAR, GZIP, BZIP2, XZ, 7Z, RAR
- **Native macOS UI** — built with SwiftUI, follows platform conventions

## Requirements

- macOS 15 (Sequoia) or later
- Xcode 16+ (for development)

## Build & Run

```bash
make build    # swift build
make release  # swift build -c release
make run      # swift run
```

## Test

```bash
make test     # swift test
```

## Lint

```bash
make lint     # swiftlint --strict
```

## License

MIT
