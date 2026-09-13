# Flash Mask

Source code for the Flash Mask Mac app. Turn selected image regions into JSON coordinates for AI agents, with optional black-and-white PNG masks.

Flash Mask describes where an edit should happen. It does not call AI services or edit the image for you. Images, selections, prompts and exported results are processed locally on your device.

## Features

- Import PNG, JPEG/JPG and WebP images; zoom and pan.
- Outline multiple irregular regions and adjust their positions and vertices.
- Add an optional prompt and copy JSON with both pixel and normalized coordinates.
- Export a black-and-white PNG mask at the original image dimensions: white selections on a black background, combining all regions.
- Include the local image path in JSON exported by the Mac app.
- Use the app in English or Chinese.

## Scope

This repository provides the Mac app source, including its AppKit / WKWebView shell, embedded HTML/JavaScript editing core, JSON schemas and core tests. The app loads `index.html` through WKWebView, so the HTML/JavaScript files are required app resources.

No standalone web-app launcher or deployment entry point is provided. The website's marketing pages, animations, quota and advertising services, analytics and operations are excluded. Shared platform semantics remain in the core and tests; the source license permits adapting the editor for the web.

## Build the Mac app

Requirements: an Apple Silicon Mac running macOS 26 or later, and a full Xcode installation with the macOS 26 SDK. The project uses Swift, AppKit and WebKit, with no external Swift package dependencies.

Run from the repository root:

```sh
xcodebuild \
  -project 'macos/Flash Mask.xcodeproj' \
  -scheme 'Flash Mask' \
  -configuration Release \
  -derivedDataPath '.derivedData/local' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Output: `.derivedData/local/Build/Products/Release/Flash Mask.app`. This unsigned local build verifies compilation and resource packaging; it is not an App Store distribution package. This command was verified with Xcode 26.6 on macOS 26.6.2.

For signed builds or running through Xcode, configure your own development team in Signing & Capabilities. When distributing a derivative, use your own bundle identifier and branding, and handle signing and platform review. The original product identifier in this project identifies the upstream source.

Visit the [Flash Mask website](https://flashmask.net/) for the official app's purchase and update channel. This repository does not provide app installers.

## Tests

Requires Node.js 22 or later. Node.js dependencies are only used for core tests; building the Mac app does not require Node.js.

```sh
npm ci --ignore-scripts
npm test
```

Tests cover JSON contracts, platform-specific fields, region geometry, selection cleanup, mask pixels and performance limits. They do not replace interactive app or browser validation.

## Source layout

| Path | Purpose |
|---|---|
| `index.html` | The Mac app's embedded editing interface and interactions |
| `src/` | Coordinate contracts, mask generation and selection cleanup |
| `schemas/` | JSON schemas and platform-specific field constraints |
| `macos/` | AppKit / WKWebView shell and Xcode project |
| `tests/` | Core tests and synthetic contract fixtures |

## License

Original source code is licensed under the [Apache License 2.0](LICENSE), which permits commercial use, modification and closed-source distribution, subject to its terms. See [NOTICE](NOTICE) for attribution and [third-party notices](THIRD_PARTY_NOTICES.md) for dependency licenses.

The Flash Mask name, logo and app icon have separate [brand asset terms](BRAND_ASSETS.md). The source license does not grant brand rights. JSON, masks and other work you create with the app are not required to use Apache-2.0 merely because you used this tool.
