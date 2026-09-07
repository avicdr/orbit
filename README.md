# Orbit

Orbit is a privacy-first, native Personal Context OS for iPhone, Mac, and Apple Watch. It will use deterministic, local computation—not remote AI APIs—to help a person understand what deserves attention now.

## Foundation status

Milestone 9 adds a macOS planning timeline with persisted task placements, drag-and-drop scheduling, resizing, free blocks, conflict detection, and explicit confirmation before overlap is saved.

## Requirements

- Xcode 26.6 or later
- iOS 17+, macOS 14+, watchOS 10+

## Build and test

```sh
swift test
xcodebuild -project Orbit.xcodeproj -target Orbit-iOS -sdk iphonesimulator build
xcodebuild -project Orbit.xcodeproj -target Orbit-macOS -sdk macosx build
xcodebuild -project Orbit.xcodeproj -target Orbit-watchOS -sdk watchsimulator build
```

See [ARCHITECTURE.md](ARCHITECTURE.md) and [PRODUCT.md](PRODUCT.md) for the architecture and product boundaries.
