import AppKit
import WebKit
import Foundation
import CryptoKit

private struct LocalizationUITestFailure: Error { let message: String }

@MainActor
private final class LocalizationUIRunner {
    let delegate = FlashMaskAppDelegate()
    let catalog = FlashMaskLocalizationCatalog.bundled
    let fixtures: URL
    let screenshots: URL
    var checks = 0
    var copiedText: String?
    var results: [String: Any] = [:]
    var controller: FlashMaskController { delegate.controller! }
    var window: NSWindow { delegate.window! }

    init(fixtures: URL, screenshots: URL) {
        self.fixtures = fixtures
        self.screenshots = screenshots
    }

    func check(_ condition: Bool, _ message: String) throws {
        checks += 1
        if !condition { throw LocalizationUITestFailure(message: message) }
    }

    func text(_ key: String, _ language: String, _ arguments: [String: String] = [:]) -> String {
        catalog.string(key, language: language, arguments: arguments)!
    }

    func javascript(_ expression: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            controller.webView.evaluateJavaScript(expression) { value, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: value) }
            }
        }
    }

    func wait(_ label: String, predicate: @escaping () async throws -> Bool) async throws {
        for _ in 0..<120 {
            if (try? await predicate()) == true { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw LocalizationUITestFailure(message: "timeout: \(label)")
    }

    func normalized(_ value: Any) throws -> String {
        String(data: try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed]), encoding: .utf8)!
    }

    func actualMaskPNG() async throws -> Data {
        _ = try await javascript("FlashMaskP0.prepareMaskDownload()")
        let bytes: [NSNumber] = try await withCheckedThrowingContinuation { continuation in
            controller.webView.callAsyncJavaScript("return Array.from(new Uint8Array(await window.__localizationTestMaskBlob.arrayBuffer()));", arguments: [:], in: nil, in: .page) { result in
                switch result {
                case .success(let value):
                    guard let values = value as? [NSNumber] else {
                        continuation.resume(throwing: LocalizationUITestFailure(message: "actual export PNG bytes"))
                        return
                    }
                    continuation.resume(returning: values)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
        return Data(bytes.map(\.uint8Value))
    }

    func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func changeLanguage(_ preference: String) async {
        await withCheckedContinuation { continuation in
            controller.setLanguagePreference(preference) {
                self.delegate.installMainMenu()
                self.delegate.reloadSettingsCopy()
                continuation.resume()
            }
        }
    }

    func screenshot(_ name: String) async throws {
        let image: NSImage = try await withCheckedThrowingContinuation { continuation in
            controller.webView.takeSnapshot(with: nil) { image, error in
                if let image { continuation.resume(returning: image) }
                else { continuation.resume(throwing: error ?? LocalizationUITestFailure(message: "snapshot \(name)")) }
            }
        }
        guard let data = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: data)?.representation(using: .png, properties: [:]) else {
            throw LocalizationUITestFailure(message: "PNG snapshot \(name)")
        }
        try png.write(to: screenshots.appendingPathComponent("\(name).png"))
    }

    func settingsScreenshot(_ language: String) throws {
        let panel = delegate.settingsController!.panel
        panel.layoutSubtreeIfNeeded()
        guard let bitmap = panel.bitmapImageRepForCachingDisplay(in: panel.bounds) else {
            throw LocalizationUITestFailure(message: "settings bitmap")
        }
        panel.cacheDisplay(in: panel.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: screenshots.appendingPathComponent("\(language)-settings.png"))
    }

    func verifyEmptyLayouts() async throws {
        let screens = NSScreen.screens
        let screenInfo: [[String: Any]] = screens.enumerated().map { index, screen in
            ["index": index, "frame": NSStringFromRect(screen.frame), "visible_frame": NSStringFromRect(screen.visibleFrame), "backing_scale_factor": screen.backingScaleFactor]
        }
        var layouts: [[String: Any]] = []
        for language in catalog.supportedLocales {
            await changeLanguage(language)
            // These are AppKit points / CSS pixels, independent of display backing scale.
            var cases: [(String, NSSize, NSScreen?)] = [
                ("default", NSSize(width: 1200, height: 780), nil),
                ("minimum", NSSize(width: 900, height: 620), nil),
                ("compact-width", NSSize(width: 1000, height: 700), nil),
                ("compact-height", NSSize(width: 1200, height: 620), nil)
            ]
            for (index, screen) in screens.enumerated() {
                cases.append(("screen-\(index)-default", NSSize(width: 1200, height: 780), screen))
                cases.append(("screen-\(index)-minimum", NSSize(width: 900, height: 620), screen))
            }
            for (name, size, screen) in cases {
                window.setContentSize(size)
                if let screen {
                    let available = screen.visibleFrame
                    let width = min(window.frame.width, available.width)
                    let height = min(window.frame.height, available.height)
                    window.setFrame(NSRect(x: available.midX - width / 2, y: available.midY - height / 2, width: width, height: height), display: true)
                    try check(window.screen === screen, "QA window on screen \(index)")
                    try check(available.insetBy(dx: -1, dy: -1).contains(window.frame), "QA initial frame within available screen")
                }
                window.layoutIfNeeded()
                try await Task.sleep(nanoseconds: 150_000_000)
                try await wait("empty viewport layout") {
                    let viewport = try await self.javascript("({width:innerWidth,height:innerHeight})") as! [String: NSNumber]
                    return abs(viewport["width"]!.doubleValue - self.controller.webView.bounds.width) < 1 && abs(viewport["height"]!.doubleValue - self.controller.webView.bounds.height) < 1
                }
                var layout = try await javascript(Self.emptyLayoutJavaScript) as! [String: Any]
                layout["locale"] = language
                layout["case"] = name
                layout["requested_content_size"] = ["width": size.width, "height": size.height]
                layout["screen_constrained"] = controller.webView.bounds.size != size
                layout["window_frame"] = NSStringFromRect(window.frame)
                layout["screen_index"] = screens.firstIndex { $0 === window.screen } ?? -1
                layout["backing_scale_factor"] = window.backingScaleFactor
                layouts.append(layout)
                try await screenshot("\(language)-empty-\(name)")
            }
        }
        let report: [String: Any] = ["unit": "AppKit points / CSS pixels", "screens": screenInfo, "layouts": layouts]
        try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted]).write(to: screenshots.appendingPathComponent("empty-layout.json"))
        for layout in layouts {
            let label = "\(layout["locale"]!) \(layout["case"]!)"
            try check(layout["dropTitle"] as? String == text("editor.dropTitle", layout["locale"] as! String), "\(label) localized empty title")
            try check(layout["scrollTop"] as? Int == 0 && layout["scrollLeft"] as? Int == 0, "\(label) starts without scrolling")
            try check(layout["overflowY"] as? Int == 0 && layout["overflowX"] as? Int == 0, "\(label) empty guide has no overflow")
            try check(layout["panelOverflowY"] as? Int == 0 && layout["panelOverflowX"] as? Int == 0, "\(label) side panel has no overflow")
            let items = layout["items"] as! [[String: Any]]
            try check(items.count == 9, "\(label) heading, subtitle, three steps and all use cases measured")
            for item in items {
                try check(item["insideGuide"] as? Bool == true && item["insidePanel"] as? Bool == true && item["insideViewport"] as? Bool == true, "\(label) \(item["key"]!) fully visible at scrollTop zero")
                try check(item["textFits"] as? Bool == true, "\(label) \(item["key"]!) complete text fits its box")
            }
        }
    }

    func verifyNative(_ language: String) throws {
        let titles = flashMaskMainMenuTitles(isChinese: language.hasPrefix("zh"), language: language)
        try check(NSApp.mainMenu?.items.map(\.title) == ["Flash Mask", titles.file, titles.edit, titles.window, titles.help], "\(language) main menu")
        let appMenu = NSApp.mainMenu!.item(at: 0)!.submenu!
        try check(appMenu.item(at: 0)?.title == text("native.menu.settings", language), "\(language) settings menu")
        try check(appMenu.item(at: 1)?.title == text("native.update.check", language), "\(language) update menu")
        let menu = controller.makeLanguageMenu()
        try check(menu.items.compactMap { $0.representedObject as? String } == ["system"] + catalog.supportedLocales, "\(language) discovered menu")
        try check(menu.item(at: 0)?.title == text("native.language.system", language), "\(language) system choice")
        try check(menu.items.dropFirst().map(\.title) == catalog.supportedLocales.map { catalog.resources[$0]!.nativeName }, "language autonyms")
        let settings = delegate.settingsController!
        let snapshot = settings.panel.snapshot()
        try check(settings.window.title == text("native.settings.title", language), "\(language) window title")
        for (field, key) in [("help", "native.help.userGuide"), ("feedback", "native.help.feedback"), ("website", "native.settings.website"), ("source", "native.settings.source"), ("check", "native.update.check")] {
            try check(snapshot[field] as? String == text(key, language), "\(language) settings \(field)")
        }
        try check(snapshot["version"] as? String == text("native.version.withBuild", language, ["version": "1.2", "build": "7"]), "\(language) version")
        try check(settings.panel.languagePopup.itemArray.compactMap { $0.representedObject as? String } == ["system"] + catalog.supportedLocales, "settings discovered menu")
        let checking = flashMaskCheckingAlert(isChinese: false, language: language)
        try check(checking.title == text("native.update.checking", language), "checking alert")
        let outcomes: [(FlashMaskUpdateFailure, String)] = [(.storefrontUnknown, "storefrontUnknown"), (.emptyResult, "emptyResult"), (.identityMismatch, "identityMismatch"), (.invalidVersion, "invalidVersion"), (.timeout, "timeout"), (.rateLimited, "rateLimited"), (.network, "network"), (.invalidResponse, "invalidResponse")]
        for (reason, key) in outcomes {
            try check(flashMaskUpdateFailureCopy(reason, isChinese: false, language: language) == text("native.update.failure.\(key)", language), "\(language) failure \(key)")
        }
        let incompatible = flashMaskUpdateAlert(outcome: .incompatible(storeVersion: "2.0", minimumOS: "27"), isChinese: false, language: language)
        try check(incompatible.title == text("native.update.incompatible", language, ["version": "2.0", "minimum_os": "27"]), "version interpolation")
        let rawError = "System error {count}: /tmp/テスト.png"
        try check(text("native.paste.chooseLocationBody", language, ["error": rawError]).hasSuffix(rawError), "raw system error preserved")
        try check(flashMaskExternalURL(destination: "help", language: language)?.path == (language.hasPrefix("zh") ? "/zh/help" : "/help"), "help route")
        try check(flashMaskOwnedFilePanelPrompt(isOpen: true, language: language) == text("native.panel.open", language), "owned open prompt")
        try check(flashMaskOwnedFilePanelPrompt(isOpen: false, language: language) == text("native.panel.save", language), "owned save prompt")
    }

    func verifyEditor(_ language: String, count: Int) async throws {
        let ui = try await javascript(Self.uiJavaScript) as! [String: Any]
        try check(ui["language"] as? String == catalog.resources[language]!.htmlLanguage, "\(language) html lang")
        try check(ui["button"] as? String == catalog.resources[language]!.nativeName, "\(language) language button")
        try check(ui["chooseLanguage"] as? String == text("editor.aria.chooseLanguage", language), "\(language) language aria")
        try check(ui["expanded"] as? String == "false", "menu closed")
        try check(ui["areaTabs"] as? String == text("editor.aria.areaTabs", language), "area tabs aria")
        let plural = try await javascript("new Intl.PluralRules(document.documentElement.lang).select(\(count))") as! String
        try check(ui["count"] as? String == text("dynamic.regionCount.\(plural == "one" ? "one" : "other")", language, ["count": String(count)]), "\(language) plural count \(count)")
        let labels = ui["areaLabels"] as! [String]
        let ids = ui["ids"] as! [Int]
        try check(labels == ids.map { text("dynamic.regionLabel", language, ["id": String($0)]) }, "numbered aria")
        let aria = ui["aria"] as! [String: String]
        for (key, value) in aria { try check(value == text("editor.aria.\(key)", language), "\(language) aria \(key)") }
        let copy = ui["copy"] as! [String: Any]
        let export = ui["export"] as! [String: Any]
        let toolbar = ui["toolbar"] as! [String: Any]
        let navigation = ui["navigation"] as! [String: Bool]
        try check(navigation["selectedWithinArea"] == true && navigation["selectedWithinNavigation"] == true, "\(language) selected ID fully visible in area and navigation")
        try check(navigation["overallReachable"] == true && navigation["deleteReachable"] == true, "\(language) overall and delete controls fully reachable")
        if count > 0 { try check(navigation["oneCompleteID"] == true, "\(language) at least one complete ID visible") }
        try check(toolbar["visible"] as? Bool == true && (toolbar["height"] as! Double) <= 108, "toolbar fits without vertical letter columns")
        if count > 0 { try check(copy["visible"] as? Bool == true && export["visible"] as? Bool == true, "result controls reachable") }
        try check(copy["text"] as? String == text("editor.copyJson", language), "copy label")
        try check(export["text"] as? String == text("editor.exportMask", language), "export label")
    }

    func menuClose(_ outside: Bool) async throws {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        for _ in 0..<40 {
            if NSApp.isActive && window.isKeyWindow { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        var focus: [String: Any] = ["active": NSApp.isActive, "key_window": window.isKeyWindow, "main_window": window.isMainWindow]
        let focusReport = screenshots.appendingPathComponent(outside ? "menu-focus-outside.json" : "menu-focus-escape.json")
        try JSONSerialization.data(withJSONObject: focus, options: [.sortedKeys]).write(to: focusReport)
        try check(NSApp.isActive && window.isKeyWindow, "native menu input requires an active app and key window")
        var sawMenu = false
        var neededFallback = false
        let timer = Timer(timeInterval: 0.25, repeats: false) { _ in
            MainActor.assumeIsolated {
            guard self.controller.languageMenu != nil else { return }
            sawMenu = true
            if outside {
                for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                    if let event = NSEvent.mouseEvent(with: type, location: NSPoint(x: 30, y: 30), modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: self.window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1) {
                        NSApp.postEvent(event, atStart: false)
                    }
                }
            } else if let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: self.window.windowNumber, context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53) {
                NSApp.postEvent(event, atStart: false)
            }
            }
        }
        let fallback = Timer(timeInterval: 1.2, repeats: false) { _ in
            MainActor.assumeIsolated {
            if let menu = self.controller.languageMenu { neededFallback = true; menu.cancelTracking() }
            }
        }
        for timer in [timer, fallback] { RunLoop.main.add(timer, forMode: .common); RunLoop.main.add(timer, forMode: .eventTracking) }
        _ = try await javascript("document.querySelector('#language-toggle').focus(); document.querySelector('#language-toggle').dispatchEvent(new KeyboardEvent('keydown', {key:'ArrowDown', bubbles:true, cancelable:true})); true")
        try await wait("native language menu close") {
            guard self.controller.languageMenu == nil else { return false }
            return try await self.javascript("document.activeElement.id === 'language-toggle' && document.querySelector('#language-toggle').getAttribute('aria-expanded') === 'false'") as? Bool == true
        }
        timer.invalidate(); fallback.invalidate()
        focus["saw_menu"] = sawMenu
        focus["needed_fallback"] = neededFallback
        focus["active_after_menu"] = NSApp.isActive
        focus["key_window_after_menu"] = window.isKeyWindow
        try JSONSerialization.data(withJSONObject: focus, options: [.sortedKeys]).write(to: focusReport)
        try check(sawMenu && !neededFallback, outside ? "outside click closes native menu" : "Escape closes native menu")
    }

    func verifySettingsErrorLayout() async throws {
        let baseline = try normalized(try await javascript(Self.stableJavaScript)!)
        var intercepted = 0
        delegate.resourceOpenHandler = { _ in intercepted += 1; return false }
        delegate.updateOpenHandler = { _ in intercepted += 1; return false }
        let notes = "Untranslated release notes 原文 {count}"
        let body: [String: Any] = ["resultCount": 1, "results": [["trackId": flashMaskAppStoreTrackID, "bundleId": "com.331workc.flashmask", "version": "2.0", "minimumOsVersion": "13.0", "releaseNotes": notes]]]
        let data = try JSONSerialization.data(withJSONObject: body)
        for language in catalog.supportedLocales {
            await changeLanguage(language)
            delegate.presentSettings(focusLanguage: false, startCheck: false)
            delegate.updateChecker = FlashMaskUpdateChecker(storefrontProvider: { $0("USA") }, localVersionProvider: { "1.3" }, fetcher: { _, _, completion in completion(.success(status: 200, body: data)) })
            delegate.checkForUpdates(nil)
            let panel = delegate.settingsController!.panel
            try check(panel.snapshot()["kind"] as? String == "available", "\(language) offline available state")
            try check(panel.snapshot()["resultBody"] as? String == notes, "release notes unchanged")
            NSApp.sendAction(panel.helpButton.action!, to: panel.helpButton.target, from: panel.helpButton)
            NSApp.sendAction(panel.storeButton.action!, to: panel.storeButton.target, from: panel.storeButton)
            try await Task.sleep(nanoseconds: 300_000_000)
            panel.layoutSubtreeIfNeeded()
            try check(panel.snapshot()["linkError"] as? String == text("native.settings.linkOpenFailed", language), "localized page error visible")
            try check(panel.snapshot()["storeError"] as? String == text("native.settings.storeOpenFailed", language), "localized store error visible")
            for view in [panel.checkButton, panel.storeButton, panel.languagePopup, panel.helpButton, panel.feedbackButton, panel.websiteButton, panel.sourceButton, panel.resultTitle, panel.linkErrorLabel, panel.storeErrorLabel] {
                try check(!view.isHidden && panel.bounds.contains(view.frame), "\(language) complete update/error controls inside settings")
            }
            for field in [panel.resultTitle, panel.linkErrorLabel, panel.storeErrorLabel] {
                let bounds = (field.stringValue as NSString).boundingRect(with: NSSize(width: field.frame.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: field.font!])
                try check(ceil(bounds.height) <= field.frame.height + 1, "\(language) complete error/result text fits")
            }
            try settingsScreenshot("\(language)-available-errors")
            try check(try normalized(try await javascript(Self.stableJavaScript)!) == baseline, "update/error controls preserve editor task")
        }
        try check(intercepted == catalog.supportedLocales.count * 3, "all external opens intercepted")
        delegate.settingsController!.window.orderOut(nil)
    }

    func run() async throws {
        let bundleID = Bundle.main.bundleIdentifier!
        try check(bundleID.hasPrefix("com.331workc.flashmask.localization-ui-test.") && bundleID != "com.331workc.flashmask", "isolated bundle ID")
        UserDefaults.standard.removePersistentDomain(forName: bundleID)
        UserDefaults.standard.set("en", forKey: "FlashMaskLanguage")
        let appleBefore = UserDefaults.standard.object(forKey: "AppleLanguages") as? [String]
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        controller.confirmReplaceHandler = { _ in true }
        controller.clipboardWriterOverride = { text in self.copiedText = text; return true }
        delegate.shortVersionProvider = { "1.2" }; delegate.buildNumberProvider = { "7" }
        try await wait("page ready") { try await self.javascript("Boolean(window.FlashMaskP0)") as? Bool == true }
        try check(window.contentMinSize == NSSize(width: 900, height: 620), "minimum window unchanged")
        _ = try await javascript("Object.defineProperty(navigator, 'clipboard', {configurable:true, value:{writeText:async()=>{throw Error('isolated native callback')}}}); true")
        _ = try await javascript("(() => { const original = URL.createObjectURL.bind(URL); URL.createObjectURL = blob => { if (blob.type === 'image/png') window.__localizationTestMaskBlob = blob; return original(blob); }; return true; })()")
        UserDefaults.standard.set("uninstalled", forKey: "FlashMaskLanguage")
        try check(controller.makeLanguageMenu().item(at: 0)?.state == .on, "unsupported preference marks system")
        await changeLanguage("en")
        try await verifyEmptyLayouts()
        if CommandLine.arguments.contains("--empty-only") {
            try check(UserDefaults.standard.object(forKey: "AppleLanguages") as? [String] == appleBefore, "AppleLanguages unchanged")
            results = ["ok": true, "checks": checks, "locales": catalog.supportedLocales, "isolated_bundle_id": bundleID, "empty_only": true, "apple_languages_unchanged": true]
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            window.orderOut(nil)
            return
        }
        var formats: [String] = []
        var hashes: [String: [String: String]] = [:]
        for ext in ["png", "jpeg", "webp"] {
            let file = fixtures.appendingPathComponent("synthetic.\(ext)")
            controller.importFromSelection(file)
            try await wait("import \(ext)") {
                let snapshot = try await self.javascript("FlashMaskP0.snapshot()") as? [String: Any]
                return snapshot?["current_file_path"] as? String == file.path && snapshot?["image_status"] as? String == "ready"
            }
            _ = try await javascript(Self.setupJavaScript)
            let baseline = try normalized(try await javascript(Self.stableJavaScript)!)
            let baselinePNG = try await actualMaskPNG()
            let baselineJSON = try normalized(try await javascript("FlashMaskP0.snapshot().public_json")!)
            hashes[ext] = ["json_sha256": sha256(Data(baselineJSON.utf8)), "png_sha256": sha256(baselinePNG)]
            try check((try await javascript("FlashMaskP0.snapshot().editor_region_ids") as! [Int]) == [1, 3], "stable nonconsecutive IDs")
            delegate.presentSettings(focusLanguage: false, startCheck: false)
            for language in catalog.supportedLocales {
                let menu = controller.makeLanguageMenu()
                menu.performActionForItem(at: menu.items.firstIndex { $0.representedObject as? String == language }!)
                try await wait("\(language) editor and settings") {
                    guard self.delegate.settingsController?.panel.language == language else { return false }
                    return try await self.javascript("document.documentElement.lang") as? String == self.catalog.resources[language]!.htmlLanguage
                }
                try verifyNative(language)
                try check(try normalized(try await javascript(Self.stableJavaScript)!) == baseline, "\(ext) \(language) preserves image, notes, IDs, viewport, JSON, PNG and pixels")
                try check(try await actualMaskPNG() == baselinePNG, "\(ext) \(language) actual export PNG bytes unchanged")
                let popup = delegate.settingsController!.panel.languagePopup
                let next = catalog.supportedLocales[(catalog.supportedLocales.firstIndex(of: language)! + 1) % catalog.supportedLocales.count]
                popup.selectItem(at: popup.itemArray.firstIndex { $0.representedObject as? String == next }!)
                NSApp.sendAction(popup.action!, to: popup.target, from: popup)
                try await wait("settings command \(next)") {
                    guard self.delegate.settingsController?.panel.language == next else { return false }
                    return try await self.javascript("document.documentElement.lang") as? String == self.catalog.resources[next]!.htmlLanguage
                }
                try verifyNative(next)
                try check(try normalized(try await javascript(Self.stableJavaScript)!) == baseline, "settings preserves current task")
                try check(try await actualMaskPNG() == baselinePNG, "settings preserves actual export PNG")
                await changeLanguage(language)
                if ext == "png" {
                    try settingsScreenshot(language)
                    delegate.settingsController!.window.orderOut(nil)
                    window.makeKeyAndOrderFront(nil)
                    for size in [NSSize(width: 1200, height: 780), NSSize(width: 900, height: 620)] {
                        window.setContentSize(size); window.layoutIfNeeded()
                        try await Task.sleep(nanoseconds: 100_000_000)
                        // Resizing can recenter the viewport; language switching was compared before resizing.
                        try await verifyEditor(language, count: 2)
                        try await screenshot("\(language)-image-\(Int(size.width))")
                    }
                    window.setContentSize(NSSize(width: 900, height: 620))
                    _ = try await javascript("FlashMaskP0.setViewport({zoom:4,x:30,y:40}); true")
                }
                delegate.presentSettings(focusLanguage: false, startCheck: false)
            }
            controller.makeLanguageMenu().performActionForItem(at: 0)
            let system = flashMaskResolvedInterfaceLanguage(preference: "system", supportedLocales: catalog.supportedLocales)
            try await wait("system command synchronizes") {
                guard self.delegate.settingsController?.panel.language == system else { return false }
                return try await self.javascript("document.documentElement.lang") as? String == self.catalog.resources[system]!.htmlLanguage
            }
            try verifyNative(system)
            try check(UserDefaults.standard.string(forKey: "FlashMaskLanguage") == "system", "follow system persisted separately")
            try check(try await actualMaskPNG() == baselinePNG, "system preserves actual export PNG")
            try check(UserDefaults.standard.object(forKey: "AppleLanguages") as? [String] == appleBefore, "AppleLanguages unchanged")
            copiedText = nil
            controller.clickCopy()
            try await wait("isolated copy") { self.copiedText != nil }
            let copied = try JSONSerialization.jsonObject(with: Data(copiedText!.utf8))
            try check(try normalized(copied) == normalized(try await javascript("FlashMaskP0.snapshot().public_json")!), "copied JSON matches current output")
            _ = try await javascript("document.querySelector('#prompt-input').blur(); FlashMaskP0.undo(); true")
            try check((try await javascript("FlashMaskP0.snapshot().editor_region_ids") as! [Int]) == [1, 2, 3], "undo history retained")
            formats.append(ext)
        }
        delegate.settingsController!.window.orderOut(nil); window.makeKeyAndOrderFront(nil)
        await changeLanguage("en")
        try await menuClose(false)
        try await menuClose(true)
        _ = try await javascript("FlashMaskP0.clearRegions(); true")
        try await verifyEditor("en", count: 0)
        _ = try await javascript(Self.drawOneJavaScript)
        try await verifyEditor("en", count: 1)
        try await verifySettingsErrorLayout()
        results = ["ok": true, "checks": checks, "locales": catalog.supportedLocales, "formats": formats, "isolated_bundle_id": bundleID, "menu_escape": true, "menu_outside": true, "apple_languages_unchanged": true, "hashes": hashes]
        UserDefaults.standard.removePersistentDomain(forName: bundleID)
        window.orderOut(nil)
    }

    static let stableJavaScript = """
    (() => {
      FlashMaskP0.prepareMaskDownload();
      const snap = FlashMaskP0.snapshot();
      const fields = ['import_nonce','origin','platform','file_name','current_file_path','image_status','path_status','viewport','editor_regions','editor_region_ids','editor_region_prompts','overall_prompt','note_scope','note_region_id','selected_region','selected_node','public_json','mask'];
      const value = Object.fromEntries(fields.map(key => [key, snap[key]]));
      value.pixels = Array.from(FlashMaskContract.rasterizeMask(snap.public_json));
      value.png = Array.from(FlashMaskContract.encodeMaskPng(snap.mask.png_width,snap.mask.png_height,new Uint8Array(value.pixels)));
      value.mask_url = document.querySelector('#download-mask').href;
      return value;
    })()
    """

    static let emptyLayoutJavaScript = """
    (() => {
      const guide=document.querySelector('#empty-guide'),panel=guide.parentElement;
      guide.scrollTop=0;guide.scrollLeft=0;
      const rect=e=>{const r=e.getBoundingClientRect();return{left:r.left,top:r.top,right:r.right,bottom:r.bottom,width:r.width,height:r.height}};
      const inside=(a,b)=>a.left>=b.left-1&&a.right<=b.right+1&&a.top>=b.top-1&&a.bottom<=b.bottom+1;
      const g=rect(guide),p=rect(panel),viewport={left:0,top:0,right:innerWidth,bottom:innerHeight};
      const items=[...guide.querySelectorAll('h2,p,.guide-step > [data-i18n],.guide-cases strong,.guide-cases li')].map(e=>{
        const r=rect(e),range=document.createRange();range.selectNodeContents(e);
        return{key:e.dataset.i18n,rect:r,text:e.textContent,textFits:e.scrollWidth<=e.clientWidth+1&&e.scrollHeight<=e.clientHeight+1&&[...range.getClientRects()].every(t=>inside(t,r)),insideGuide:inside(r,g),insidePanel:inside(r,p),insideViewport:inside(r,viewport)};
      });
      return{viewport:{width:innerWidth,height:innerHeight},guide:g,panel:p,scrollTop:guide.scrollTop,scrollLeft:guide.scrollLeft,clientHeight:guide.clientHeight,scrollHeight:guide.scrollHeight,overflowY:Math.max(0,guide.scrollHeight-guide.clientHeight),overflowX:Math.max(0,guide.scrollWidth-guide.clientWidth),panelOverflowY:Math.max(0,panel.scrollHeight-panel.clientHeight),panelOverflowX:Math.max(0,panel.scrollWidth-panel.clientWidth),dropTitle:document.querySelector('[data-i18n=dropTitle]').textContent,items};
    })()
    """

    static let drawOneJavaScript = """
    (() => {
      const overlay=document.querySelector('#selection-overlay'),b=overlay.getBoundingClientRect();
      for(const [type,p] of [['pointerdown',[.05,.05]],['pointermove',[.366667,.05]],['pointermove',[.366667,.45]],['pointermove',[.05,.45]],['pointerup',[.05,.45]]])
        overlay.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:51,button:0,clientX:b.left+p[0]*b.width,clientY:b.top+p[1]*b.height}));
      return true;
    })()
    """

    static let setupJavaScript = """
    (() => {
      const overlay=document.querySelector('#selection-overlay');
      const draw=(points,id)=>{const b=overlay.getBoundingClientRect();const fire=(type,p)=>overlay.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:id,button:0,clientX:b.left+p[0]*b.width,clientY:b.top+p[1]*b.height}));fire('pointerdown',points[0]);points.slice(1).forEach(p=>fire('pointermove',p));fire('pointerup',points.at(-1));};
      draw([[.05,.05],[.366667,.05],[.366667,.45],[.05,.45]],41);
      draw([[.6,.05],[.9,.05],[.9,.45],[.6,.45]],42);
      draw([[.05,.55],[.366667,.55],[.366667,.9],[.05,.9]],43);
      const input=document.querySelector('#prompt-input');
      const note=(selector,value)=>{document.querySelector(selector).click();input.value=value;input.dispatchEvent(new Event('input',{bubbles:true}));};
      note('#overall-tab','Keep 原文 {count} <b>全体</b>');
      note('#area-tabs [data-area="1"]','第一区域 Japanese 日本語');
      note('#area-tabs [data-area="3"]','第三域\\n{error} unchanged');
      document.querySelector('#area-tabs [data-area="2"]').click();document.querySelector('#delete-note-region').click();
      document.querySelector('#area-tabs [data-area="3"]').click();
      input.blur();FlashMaskP0.setViewport({zoom:4,x:30,y:40});return true;
    })()
    """

    static let uiJavaScript = """
    (()=>{const q=s=>document.querySelector(s),box=e=>{const r=e.getBoundingClientRect();return{text:e.textContent.trim(),height:r.height,visible:r.width>0&&r.height>0&&r.top>=0&&r.bottom<=innerHeight&&r.left>=0&&r.right<=innerWidth}};
      const within=(inner,outer)=>{const a=inner.getBoundingClientRect(),b=outer.getBoundingClientRect();return a.left>=b.left-1&&a.right<=b.right+1&&a.top>=b.top-1&&a.bottom<=b.bottom+1};
      const nav=q('#note-navigation'),areas=q('#area-tabs'),selected=areas.querySelector('[aria-pressed=true]'),overall=q('#overall-tab'),remove=q('#delete-note-region');
      const navigation={selectedWithinArea:!selected||within(selected,areas),selectedWithinNavigation:!selected||within(selected,nav),overallReachable:within(overall,nav)&&overall.scrollHeight<=overall.clientHeight+1&&overall.scrollWidth<=overall.clientWidth+1,deleteReachable:within(remove,nav)&&box(remove).visible,oneCompleteID:[...areas.children].some(e=>within(e,areas)&&within(e,nav))};
      return{language:document.documentElement.lang,button:q('#language-toggle span').textContent,chooseLanguage:q('#language-toggle').getAttribute('aria-label'),expanded:q('#language-toggle').getAttribute('aria-expanded'),areaTabs:q('#area-tabs').getAttribute('aria-label'),count:q('#region-count').textContent,areaLabels:[...q('#area-tabs').children].map(e=>e.getAttribute('aria-label')),ids:FlashMaskP0.snapshot().editor_region_ids,navigation,copy:box(q('#copy-json')),export:box(q('#download-mask')),toolbar:box(q('#floating-toolbar')),aria:{previewAlt:q('#preview').alt,selector:q('#selection-overlay').getAttribute('aria-label'),toolbar:q('#toolbar-handle').getAttribute('aria-label'),zoomIn:q('#zoom-in').getAttribute('aria-label'),zoomOut:q('#zoom-out').getAttribute('aria-label'),actualSize:q('#actual-size-action').getAttribute('aria-label'),actualSizeHint:q('#actual-size-action').title,panHorizontal:q('#canvas-scrollbar-x').getAttribute('aria-label'),panVertical:q('#canvas-scrollbar-y').getAttribute('aria-label'),website:q('#website-link').getAttribute('aria-label'),github:q('#github-link').getAttribute('aria-label')}};})()
    """
}

@main
struct MacLocalizationUIMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.activate(ignoringOtherApps: true)
        let runner = LocalizationUIRunner(fixtures: URL(fileURLWithPath: CommandLine.arguments[1]), screenshots: URL(fileURLWithPath: CommandLine.arguments[2]))
        Task { @MainActor in
            do {
                try await runner.run()
                let data = try JSONSerialization.data(withJSONObject: runner.results, options: [.sortedKeys])
                print(String(data: data, encoding: .utf8)!)
                exit(0)
            } catch {
                let message = (error as? LocalizationUITestFailure)?.message ?? error.localizedDescription
                fputs("localization UI failure after \(runner.checks) checks: \(message)\n", stderr)
                exit(1)
            }
        }
        app.run()
    }
}
