import Foundation

@main
struct MacLocalizationMain {
    static func main() throws {
        let fixtureRoot = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        var failures: [String] = []
        var checks = 0
        func check(_ label: String, _ condition: @autoclosure () -> Bool) {
            checks += 1
            if !condition() { failures.append(label) }
        }

        let all = ["en", "zh", "ja", "de", "fr", "es", "zh-Hant"]
        let canonical: [(String, String)] = [
            ("zh-Hans-TW", "zh"), ("zh-Hant-CN", "zh-Hant"), ("zh-TW", "zh-Hant"),
            ("zh-HK", "zh-Hant"), ("zh-MO", "zh-Hant"), ("zh-CN", "zh"), ("zh-SG", "zh"),
            ("zh_Hant_HK", "zh-Hant"), ("zh", "zh"), ("ja-JP", "ja"), ("de-AT", "de"),
            ("fr-CA", "fr"), ("es-MX", "es"), ("en-GB", "en")
        ]
        for (input, expected) in canonical {
            check("canonical-\(input)", flashMaskCanonicalLanguage(input) == expected)
            check("matching-\(input)", flashMaskMatchingInterfaceLanguage([input], supportedLocales: all) == expected)
        }
        check("ordered-non-first", flashMaskMatchingInterfaceLanguage(["ko-KR", "ja-JP", "en-US"], supportedLocales: all) == "ja")
        check("ordered-installed-only", flashMaskMatchingInterfaceLanguage(["ko", "ja", "de"], supportedLocales: ["en", "de"]) == "de")
        check("no-supported-language", flashMaskMatchingInterfaceLanguage(["ko", "it"], supportedLocales: all) == "en")
        check("no-false-prefix", flashMaskMatchingInterfaceLanguage(["english", "zho", "ja-JP"], supportedLocales: all) == "ja")
        check("uninstalled-traditional", flashMaskMatchingInterfaceLanguage(["zh-Hant-TW", "ja"], supportedLocales: ["en", "zh", "ja"]) == "ja")
        check("old-zh", flashMaskResolvedInterfaceLanguage(preference: "zh", preferredLanguages: ["ja"], supportedLocales: all) == "zh")
        check("old-en", flashMaskResolvedInterfaceLanguage(preference: "en", preferredLanguages: ["ja"], supportedLocales: all) == "en")
        check("old-system", flashMaskResolvedInterfaceLanguage(preference: "system", preferredLanguages: ["ko", "ja"], supportedLocales: all) == "ja")
        check("explicit-ja", flashMaskResolvedInterfaceLanguage(preference: "ja", preferredLanguages: ["de"], supportedLocales: all) == "ja")
        check("invalid-preference", flashMaskResolvedInterfaceLanguage(preference: "bogus", preferredLanguages: ["fr"], supportedLocales: all) == "fr")
        check("missing-preference-resource", flashMaskResolvedInterfaceLanguage(preference: "de", preferredLanguages: ["ja"], supportedLocales: ["en", "zh", "ja"]) == "ja")

        let catalog = FlashMaskLocalizationCatalog.bundled
        check("bundle-discovers-lproj", Set(Bundle.main.localizations) == Set(["en", "ja", "zh-Hans"]))
        check("only-installed-resources", catalog.supportedLocales == ["zh", "en", "ja"])
        check("valid-bundle", catalog.validationFailures.isEmpty)
        check("complete-keys", catalog.resources.values.allSatisfy { $0.strings.count == 132 })
        check("no-fake-support", !catalog.supportedLocales.contains("de") && !catalog.supportedLocales.contains("zh-Hant"))
        check("japanese-prompt", flashMaskOwnedFilePanelPrompt(isOpen: true, language: "ja") == "開く")
        check("japanese-save", flashMaskOwnedFilePanelPrompt(isOpen: false, language: "ja") == "保存")
        check("panel-script-priority", flashMaskMatchingPanelLanguage(["zh-Hant-CN", "ja"], bundleLocalizations: ["en", "zh-Hans", "zh-Hant", "ja"]) == "zh-Hant")
        check("panel-non-first", flashMaskMatchingPanelLanguage(["ko", "ja"], bundleLocalizations: ["en", "ja"]) == "ja")
        check("panel-missing-resource", flashMaskMatchingPanelLanguage(["ja"], bundleLocalizations: ["en", "zh-Hans"]) == "en")
        check("version-format", catalog.string("native.version.withBuild", language: "ja", arguments: ["version": "1.2", "build": "7"]) == "バージョン 1.2（ビルド 7）")
        check("minimum-os-format", catalog.string("native.update.incompatible", language: "ja", arguments: ["version": "1.3", "minimum_os": "14.0"]) == "バージョン 1.3 には macOS 14.0 以降が必要です。")
        check("missing-token-rejected", catalog.string("native.version.withBuild", language: "ja", arguments: ["version": "1.2"]) == nil)
        check("extra-token-rejected", catalog.string("native.panel.open", language: "ja", arguments: ["id": "1"]) == nil)
        check("runtime-english-fallback", catalog.string("native.panel.open", language: "de") == "Open")
        check("singular-count-token", catalog.string("dynamic.regionCount.one", language: "en", arguments: ["count": "1"]) == "1 area")
        check("zero-count-token", catalog.string("dynamic.regionCount.other", language: "en", arguments: ["count": "0"]) == "0 areas")
        check("stable-id-token", catalog.string("dynamic.regionLabel", language: "ja", arguments: ["id": "8"]) == "領域 8")
        let error = "system {error} <原文> 👁️"
        check("error-is-not-reinterpreted", catalog.string("native.paste.chooseLocationBody", language: "ja", arguments: ["error": error])?.hasSuffix("\n\(error)") == true)

        for name in ["missing-key", "different-key", "wrong-token", "duplicate-token", "bad-html", "wrong-metadata"] {
            let invalid = FlashMaskLocalizationCatalog(resourceDirectory: fixtureRoot.appendingPathComponent(name), bundleLocalizations: ["en", "zh-Hans", "ja"])
            check("reject-\(name)", invalid.resources["ja"] == nil && invalid.validationFailures.contains("ja.json"))
            check("reject-\(name)-keeps-base", invalid.supportedLocales == ["zh", "en"])
        }
        let missingLproj = FlashMaskLocalizationCatalog(resourceDirectory: fixtureRoot.appendingPathComponent("valid"), bundleLocalizations: ["en", "zh-Hans"])
        check("missing-lproj-not-advertised", missingLproj.resources["ja"] == nil)
        let missingEnglish = FlashMaskLocalizationCatalog(resourceDirectory: fixtureRoot.appendingPathComponent("missing-english"), bundleLocalizations: ["zh-Hans", "ja"])
        check("canonical-resource-required", missingEnglish.resources.isEmpty)

        let suiteName = "com.331workc.flashmask.localization-test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.register(defaults: ["AppleLanguages": ["fr"]])
        let appleLanguagesBefore = defaults.array(forKey: "AppleLanguages") as? [String]
        flashMaskPersistLanguagePreference("ja", defaults: defaults, supportedLocales: catalog.supportedLocales)
        check("persist-installed", defaults.string(forKey: "FlashMaskLanguage") == "ja")
        check("no-apple-languages-write", defaults.persistentDomain(forName: suiteName)?["AppleLanguages"] == nil)
        check("existing-system-language-unchanged", defaults.array(forKey: "AppleLanguages") as? [String] == appleLanguagesBefore)
        check("ui-preference-does-not-select-panel", flashMaskMatchingPanelLanguage(["zh-Hans"], bundleLocalizations: ["en", "zh-Hans", "ja"]) == "zh")
        flashMaskPersistLanguagePreference("bogus", defaults: defaults, supportedLocales: catalog.supportedLocales)
        check("invalid-persists-system", defaults.string(forKey: "FlashMaskLanguage") == "system")
        let data = try JSONSerialization.data(withJSONObject: ["ok": failures.isEmpty, "checks": checks, "failures": failures, "locales": catalog.supportedLocales, "bundle_localizations": Bundle.main.localizations, "resource_failures": catalog.validationFailures])
        print(String(data: data, encoding: .utf8)!)
        if !failures.isEmpty { exit(1) }
    }
}
