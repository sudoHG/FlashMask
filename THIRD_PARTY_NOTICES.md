# Third-party notices

The Apache-2.0 license for original source code does not replace the licenses of the components below.

| Component | Usage | License |
|---|---|---|
| Microsoft Fluent UI System Icons | Generic SVG interface icons embedded in `index.html` | MIT, Copyright (c) 2020 Microsoft Corporation; see the [full license](licenses/Fluent-UI-Icons-MIT.txt) |
| Lucide / Feather icons | Generic image, file, folder, copy, download and zoom icons in `index.html`; some paths are combined | ISC and MIT for applicable Feather-derived icons; see the [full notices and licenses](licenses/Lucide-Feather.txt) |
| Ajv 8.20.0 | JSON Schema test dependency | MIT |
| fast-deep-equal 3.1.3 | Dependency of Ajv used for tests | MIT |
| fast-uri 3.1.5 | Dependency of Ajv used for tests | BSD-3-Clause |
| json-schema-traverse 1.0.0 | Dependency of Ajv used for tests | MIT |
| require-from-string 2.0.2 | Dependency of Ajv used for tests | MIT |

Node.js test dependencies are installed with `npm ci`. Their versions and integrity hashes are pinned in `package-lock.json`, and each package includes its own license. They are not bundled into the Mac app or browser runtime resources. Preserve their licenses and copyright notices if you redistribute those dependencies.

The full licenses for both icon sets are also embedded in comments in `index.html`, so they accompany the page when distributed, including within the Mac app.

Sources: [Microsoft Fluent UI System Icons](https://github.com/microsoft/fluentui-system-icons), [Lucide](https://github.com/lucide-icons/lucide), [Ajv](https://github.com/ajv-validator/ajv).

AppKit, WebKit and UniformTypeIdentifiers are provided by the system SDK. This repository does not redistribute the Apple SDK. Brand assets are covered separately by the [brand asset terms](BRAND_ASSETS.md).
