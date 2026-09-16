import AppKit
import ImageIO
import StoreKit
import UniformTypeIdentifiers
import WebKit

let flashMaskTextUndoPredicate = "document.activeElement?.matches(':read-write') === true"

enum FlashMaskUndoDecision: Equatable {
    case nativeResponder
    case pageText
    case pageCanvas
}

func flashMaskUndoDecision(
    isMainWindow: Bool,
    nativeResponderCanUndo: Bool,
    pageHasEditableElement: Bool
) -> FlashMaskUndoDecision {
    guard isMainWindow, !nativeResponderCanUndo else { return .nativeResponder }
    return pageHasEditableElement ? .pageText : .pageCanvas
}

func flashMaskNativeUndoResponderCanUndo(firstResponder: NSResponder?, pageView: NSView?) -> Bool {
    let undoSelector = Selector(("undo:"))
    var responder = firstResponder
    while let current = responder {
        let isPageResponder = pageView.map {
            current === $0 || (current as? NSView)?.isDescendant(of: $0) == true
        } ?? false
        let isContainer = current is NSWindow || current is NSApplication
        if !isPageResponder, !isContainer {
            if let textView = current as? NSTextView, textView.isEditable { return true }
            if current.responds(to: undoSelector), current.undoManager != nil { return true }
        }
        responder = current.nextResponder
    }
    return false
}

struct FlashMaskMainMenuTitles: Equatable {
    let app: String
    let file: String
    let edit: String
    let window: String
    let help: String
}

func flashMaskMainMenuTitles(isChinese: Bool) -> FlashMaskMainMenuTitles {
    FlashMaskMainMenuTitles(
        app: "Flash Mask",
        file: isChinese ? "文件" : "File",
        edit: isChinese ? "编辑" : "Edit",
        window: isChinese ? "窗口" : "Window",
        help: isChinese ? "帮助" : "Help"
    )
}

func flashMaskExternalURL(destination: String, language: String) -> URL? {
    var components = URLComponents()
    components.scheme = "https"
    switch destination {
    case "website":
        components.host = "flashmask.net"
        components.path = language == "zh" ? "/zh/" : "/"
    case "help":
        components.host = "flashmask.net"
        components.path = language == "zh" ? "/zh/help/" : "/help/"
    case "github":
        components.host = "github.com"
        components.path = "/sudoHG/FlashMask"
    case "feedback":
        components.host = "flashmask.net"
        components.path = language == "zh" ? "/zh/support/" : "/support/"
    default:
        return nil
    }
    return components.url
}

let flashMaskAppStoreTrackID: Int64 = 6_803_817_818
let flashMaskAppStoreBundleID = "com.331workc.flashmask"
// Whole-check bound recorded for 331-474. SPEC called 15s an engineering suggestion, not a product constant.
let flashMaskUpdateCheckTimeout: TimeInterval = 15

enum FlashMaskUpdateFailure: String, Equatable, Error {
    case storefrontUnknown
    case emptyResult
    case identityMismatch
    case invalidVersion
    case timeout
    case rateLimited
    case network
    case invalidResponse
}

enum FlashMaskUpdateOutcome: Equatable {
    case available(localVersion: String, storeVersion: String, notes: String?)
    case upToDate(localVersion: String, storeVersion: String)
    case incompatible(storeVersion: String, minimumOS: String)
    case failed(FlashMaskUpdateFailure)
}

enum FlashMaskUpdateFetchResult: Equatable {
    case success(status: Int, body: Data)
    case timeout
    case network
}

struct FlashMaskUpdateAlert: Equatable {
    enum Kind: String {
        case checking
        case available
        case upToDate
        case incompatible
        case failed
        case notice
    }

    var kind: Kind
    var title: String
    var body: String
    var buttons: [String]
}

struct FlashMaskLookupApp: Equatable {
    var trackId: Int64
    var bundleId: String
    var version: String
    var releaseNotes: String?
    var minimumOsVersion: String?
}

typealias FlashMaskUpdateFetcher = (URL, TimeInterval, @escaping (FlashMaskUpdateFetchResult) -> Void) -> Void
typealias FlashMaskStorefrontProvider = (@escaping (String?) -> Void) -> Void

private let flashMaskISO3166Alpha3Records = "ANDADAREAEAFGAFATGAGAIAAIALBALARMAMAGOAOATAAQARGARASMASAUTATAUSAUABWAWALAAXAZEAZBIHBABRBBBBGDBDBELBEBFABFBGRBGBHRBHBDIBIBENBJBLMBLBMUBMBRNBNBOLBOBESBQBRABRBHSBSBTNBTBVTBVBWABWBLRBYBLZBZCANCACCKCCCODCDCAFCFCOGCGCHECHCIVCICOKCKCHLCLCMRCMCHNCNCOLCOCRICRCUBCUCPVCVCUWCWCXRCXCYPCYCZECZDEUDEDJIDJDNKDKDMADMDOMDODZADZECUECESTEEEGYEGESHEHERIERESPESETHETFINFIFJIFJFLKFKFSMFMFROFOFRAFRGABGAGBRGBGRDGDGEOGEGUFGFGGYGGGHAGHGIBGIGRLGLGMBGMGINGNGLPGPGNQGQGRCGRSGSGSGTMGTGUMGUGNBGWGUYGYHKGHKHMDHMHNDHNHRVHRHTIHTHUNHUIDNIDIRLIEISRILIMNIMINDINIOTIOIRQIQIRNIRISLISITAITJEYJEJAMJMJORJOJPNJPKENKEKGZKGKHMKHKIRKICOMKMKNAKNPRKKPKORKRKWTKWCYMKYKAZKZLAOLALBNLBLCALCLIELILKALKLBRLRLSOLSLTULTLUXLULVALVLBYLYMARMAMCOMCMDAMDMNEMEMAFMFMDGMGMHLMHMKDMKMLIMLMMRMMMNGMNMACMOMNPMPMTQMQMRTMRMSRMSMLTMTMUSMUMDVMVMWIMWMEXMXMYSMYMOZMZNAMNANCLNCNERNENFKNFNGANGNICNINLDNLNORNONPLNPNRUNRNIUNUNZLNZOMNOMPANPAPERPEPYFPFPNGPGPHLPHPAKPKPOLPLSPMPMPCNPNPRIPRPSEPSPRTPTPLWPWPRYPYQATQAREUREROUROSRBRSRUSRURWARWSAUSASLBSBSYCSCSDNSDSWESESGPSGSHNSHSVNSISJMSJSVKSKSLESLSMRSMSENSNSOMSOSURSRSSDSSSTPSTSLVSVSXMSXSYRSYSWZSZTCATCTCDTDATFTFTGOTGTHATHTJKTJTKLTKTLSTLTKMTMTUNTNTONTOTURTRTTOTTTUVTVTWNTWTZATZUKRUAUGAUGUMIUMUSAUSURYUYUZBUZVATVAVCTVCVENVEVGBVGVIRVIVNMVNVUTVUWLFWFWSMWSYEMYEMYTYTZAFZAZMBZMZWEZWXKXXK"

private let flashMaskLookupCountryByStorefront: [String: String] = {
    var map: [String: String] = [:]
    var index = flashMaskISO3166Alpha3Records.startIndex
    let records = flashMaskISO3166Alpha3Records
    while records.distance(from: index, to: records.endIndex) >= 5 {
        let alpha3End = records.index(index, offsetBy: 3)
        let alpha2End = records.index(alpha3End, offsetBy: 2)
        map[String(records[index..<alpha3End])] = String(records[alpha3End..<alpha2End]).lowercased()
        index = alpha2End
    }
    return map
}()

private let flashMaskLookupAlpha2 = Set(flashMaskLookupCountryByStorefront.values)

func flashMaskLookupCountryCode(storefrontCountryCode: String) -> String? {
    let code = storefrontCountryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard !code.isEmpty else { return nil }
    if code.count == 2 {
        if code == "UK" { return "gb" }
        let lower = code.lowercased()
        return flashMaskLookupAlpha2.contains(lower) ? lower : nil
    }
    if code.count == 3 {
        return flashMaskLookupCountryByStorefront[code]
    }
    return nil
}

func flashMaskLookupURL(countryCode: String) -> URL? {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "itunes.apple.com"
    components.path = "/lookup"
    components.queryItems = [
        URLQueryItem(name: "id", value: String(flashMaskAppStoreTrackID)),
        URLQueryItem(name: "country", value: countryCode)
    ]
    return components.url
}

func flashMaskAppStorePageURLs(countryCode: String) -> (store: URL, https: URL)? {
    let country = countryCode.lowercased()
    guard country.count == 2,
          country.unicodeScalars.allSatisfy({ CharacterSet.lowercaseLetters.contains($0) }) else { return nil }
    var store = URLComponents()
    store.scheme = "macappstore"
    store.host = "apps.apple.com"
    store.path = "/\(country)/app/id\(flashMaskAppStoreTrackID)"
    var https = URLComponents()
    https.scheme = "https"
    https.host = "apps.apple.com"
    https.path = "/\(country)/app/id\(flashMaskAppStoreTrackID)"
    guard let storeURL = store.url, let httpsURL = https.url else { return nil }
    return (storeURL, httpsURL)
}

func flashMaskGenericAppStorePageURLs() -> (store: URL, https: URL)? {
    var store = URLComponents()
    store.scheme = "macappstore"
    store.host = "apps.apple.com"
    store.path = "/app/id\(flashMaskAppStoreTrackID)"
    var https = URLComponents()
    https.scheme = "https"
    https.host = "apps.apple.com"
    https.path = "/app/id\(flashMaskAppStoreTrackID)"
    guard let storeURL = store.url, let httpsURL = https.url else { return nil }
    return (storeURL, httpsURL)
}

func flashMaskResolvedAppStorePageURLs(countryCode: String?) -> (store: URL, https: URL)? {
    if let countryCode, let urls = flashMaskAppStorePageURLs(countryCode: countryCode) {
        return urls
    }
    return flashMaskGenericAppStorePageURLs()
}

func flashMaskSettingsIconImage() -> NSImage? {
    if let url = Bundle.main.url(forResource: "FlashMask", withExtension: "icns"),
       let image = NSImage(contentsOf: url) {
        return image
    }
    let repoIcon = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("macos/FlashMask.icns")
    if FileManager.default.isReadableFile(atPath: repoIcon.path) {
        return NSImage(contentsOf: repoIcon)
    }
    return NSApp.applicationIconImage
}

func flashMaskLocalVersionLine(shortVersion: String?, build: String?, isChinese: Bool) -> String {
    let trimmedVersion = shortVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let resolvedVersion = trimmedVersion.isEmpty ? "—" : trimmedVersion
    let buildNumber = build?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !buildNumber.isEmpty {
        return isChinese
            ? "版本 \(resolvedVersion)（构建 \(buildNumber)）"
            : "Version \(resolvedVersion) (build \(buildNumber))"
    }
    return isChinese ? "版本 \(resolvedVersion)" : "Version \(resolvedVersion)"
}

func flashMaskParseAppVersion(_ raw: String) -> [Int]? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
    guard !parts.isEmpty else { return nil }
    var numbers: [Int] = []
    numbers.reserveCapacity(parts.count)
    for part in parts {
        guard !part.isEmpty, part.allSatisfy(\.isNumber), let value = Int(part) else { return nil }
        numbers.append(value)
    }
    return numbers
}

func flashMaskCompareAppVersions(_ left: String, _ right: String) -> ComparisonResult? {
    guard var first = flashMaskParseAppVersion(left), var second = flashMaskParseAppVersion(right) else { return nil }
    let count = max(first.count, second.count)
    first.append(contentsOf: Array(repeating: 0, count: count - first.count))
    second.append(contentsOf: Array(repeating: 0, count: count - second.count))
    for index in 0..<count {
        if first[index] < second[index] { return .orderedAscending }
        if first[index] > second[index] { return .orderedDescending }
    }
    return .orderedSame
}

func flashMaskOperatingSystemMeets(_ minimum: String, current: OperatingSystemVersion) -> Bool? {
    let currentText = "\(current.majorVersion).\(current.minorVersion).\(current.patchVersion)"
    guard let comparison = flashMaskCompareAppVersions(currentText, minimum) else { return nil }
    return comparison != .orderedAscending
}

func flashMaskJSONInt64(_ value: Any?) -> Int64? {
    if let number = value as? Int64 { return number }
    if let number = value as? Int { return Int64(number) }
    if let number = value as? NSNumber { return number.int64Value }
    if let text = value as? String { return Int64(text) }
    return nil
}

func flashMaskParseLookup(_ data: Data) -> Result<FlashMaskLookupApp, FlashMaskUpdateFailure> {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return .failure(.invalidResponse)
    }
    guard let results = root["results"] as? [[String: Any]] else {
        return .failure(.invalidResponse)
    }
    if results.isEmpty { return .failure(.emptyResult) }
    let match = results.first { item in
        flashMaskJSONInt64(item["trackId"]) == flashMaskAppStoreTrackID
            && (item["bundleId"] as? String) == flashMaskAppStoreBundleID
    }
    guard let item = match else { return .failure(.identityMismatch) }
    guard let version = item["version"] as? String,
          flashMaskParseAppVersion(version) != nil else {
        return .failure(.invalidVersion)
    }
    let notes = (item["releaseNotes"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let minimum = (item["minimumOsVersion"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return .success(FlashMaskLookupApp(
        trackId: flashMaskAppStoreTrackID,
        bundleId: flashMaskAppStoreBundleID,
        version: version,
        releaseNotes: (notes?.isEmpty == false) ? notes : nil,
        minimumOsVersion: (minimum?.isEmpty == false) ? minimum : nil
    ))
}

func flashMaskEvaluateUpdate(
    localVersion: String,
    storeVersion: String,
    notes: String?,
    minimumOsVersion: String?,
    currentOS: OperatingSystemVersion
) -> FlashMaskUpdateOutcome {
    guard let comparison = flashMaskCompareAppVersions(localVersion, storeVersion) else {
        return .failed(.invalidVersion)
    }
    if comparison != .orderedAscending {
        return .upToDate(localVersion: localVersion, storeVersion: storeVersion)
    }
    if let minimum = minimumOsVersion, !minimum.isEmpty {
        guard let supported = flashMaskOperatingSystemMeets(minimum, current: currentOS) else {
            return .failed(.invalidResponse)
        }
        if !supported {
            return .incompatible(storeVersion: storeVersion, minimumOS: minimum)
        }
    }
    return .available(localVersion: localVersion, storeVersion: storeVersion, notes: notes)
}

func flashMaskRequestStorefrontCountryCode(_ completion: @escaping (String?) -> Void) {
    Task {
        let code = await Storefront.current?.countryCode
        DispatchQueue.main.async { completion(code) }
    }
}

func flashMaskDefaultUpdateFetcher(
    url: URL,
    timeout: TimeInterval,
    completion: @escaping (FlashMaskUpdateFetchResult) -> Void
) {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = timeout
    configuration.timeoutIntervalForResource = timeout
    configuration.waitsForConnectivity = false
    configuration.httpCookieStorage = nil
    configuration.urlCache = nil
    configuration.httpShouldSetCookies = false
    let session = URLSession(configuration: configuration)
    let task = session.dataTask(with: url) { data, response, error in
        let result: FlashMaskUpdateFetchResult
        if let error = error as NSError?, error.domain == NSURLErrorDomain, error.code == NSURLErrorTimedOut {
            result = .timeout
        } else if error != nil {
            result = .network
        } else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            result = .success(status: status, body: data ?? Data())
        }
        DispatchQueue.main.async {
            session.finishTasksAndInvalidate()
            completion(result)
        }
    }
    task.resume()
}

func flashMaskUpdateFailureCopy(_ reason: FlashMaskUpdateFailure, isChinese: Bool) -> String {
    switch reason {
    case .storefrontUnknown:
        return isChinese ? "无法确定 App Store 地区" : "Couldn’t determine the App Store region."
    case .emptyResult:
        return isChinese ? "当前 App Store 地区未找到 Flash Mask。" : "Flash Mask wasn’t found in this App Store region."
    case .identityMismatch:
        return isChinese ? "App Store 返回的应用不符，请稍后重试。" : "The App Store returned a different app. Try again later."
    case .invalidVersion:
        return isChinese ? "无法读取版本号，请稍后重试。" : "Couldn’t read the version number. Try again later."
    case .timeout:
        return isChinese ? "检查超时，请重试。" : "The check timed out. Try again."
    case .rateLimited:
        return isChinese ? "查询次数过多，请稍后重试。" : "Too many requests. Try again later."
    case .network:
        return isChinese ? "无法连接 App Store，请检查网络。" : "Couldn’t reach the App Store. Check your connection."
    case .invalidResponse:
        return isChinese ? "无法读取 App Store 信息，请稍后重试。" : "Couldn’t read the App Store response. Try again later."
    }
}

func flashMaskCheckingAlert(isChinese: Bool) -> FlashMaskUpdateAlert {
    FlashMaskUpdateAlert(
        kind: .checking,
        title: isChinese ? "正在检查…" : "Checking…",
        body: "",
        buttons: [isChinese ? "关闭" : "Close"]
    )
}

func flashMaskUpdateAlert(outcome: FlashMaskUpdateOutcome, isChinese: Bool) -> FlashMaskUpdateAlert {
    switch outcome {
    case let .available(_, storeVersion, notes):
        return FlashMaskUpdateAlert(
            kind: .available,
            title: isChinese ? "发现新版本 \(storeVersion)" : "Version \(storeVersion) available",
            body: notes ?? "",
            buttons: [
                isChinese ? "前往 App Store" : "Go to the App Store",
                isChinese ? "关闭" : "Close"
            ]
        )
    case .upToDate:
        return FlashMaskUpdateAlert(
            kind: .upToDate,
            title: isChinese ? "已是最新版本" : "You’re up to date",
            body: "",
            buttons: [isChinese ? "关闭" : "Close"]
        )
    case let .incompatible(storeVersion, minimumOS):
        return FlashMaskUpdateAlert(
            kind: .incompatible,
            title: isChinese ? "版本 \(storeVersion) 需要 macOS \(minimumOS) 或更高版本。" : "Version \(storeVersion) requires macOS \(minimumOS) or later.",
            body: isChinese ? "请先更新 macOS，再检查 App 更新。" : "Update macOS, then check for app updates.",
            buttons: [isChinese ? "关闭" : "Close"]
        )
    case let .failed(reason):
        let retry = isChinese ? "重试" : "Retry"
        let close = isChinese ? "关闭" : "Close"
        if reason == .storefrontUnknown {
            return FlashMaskUpdateAlert(
                kind: .failed,
                title: flashMaskUpdateFailureCopy(reason, isChinese: isChinese),
                body: "",
                buttons: [
                    isChinese ? "在 App Store 中查看" : "View in App Store",
                    retry,
                    close
                ]
            )
        }
        return FlashMaskUpdateAlert(
            kind: .failed,
            title: flashMaskUpdateFailureCopy(reason, isChinese: isChinese),
            body: "",
            buttons: [retry, close]
        )
    }
}

struct FlashMaskSettingsUpdateViewModel: Equatable {
    var kind: String
    var checkTitle: String
    var checkEnabled: Bool
    var resultTitle: String?
    var resultBody: String?
    var storeTitle: String?
    var storeIsPrimary: Bool
}

func flashMaskSettingsCheckTitle(retry: Bool, isChinese: Bool) -> String {
    if retry { return isChinese ? "重试" : "Try Again" }
    return isChinese ? "检查更新…" : "Check for Updates…"
}

func flashMaskSettingsUpdateViewModel(
    checking: Bool,
    outcome: FlashMaskUpdateOutcome?,
    isChinese: Bool
) -> FlashMaskSettingsUpdateViewModel {
    if checking {
        return FlashMaskSettingsUpdateViewModel(
            kind: "checking",
            checkTitle: isChinese ? "正在检查…" : "Checking…",
            checkEnabled: false,
            resultTitle: nil,
            resultBody: nil,
            storeTitle: nil,
            storeIsPrimary: false
        )
    }
    guard let outcome else {
        return FlashMaskSettingsUpdateViewModel(
            kind: "idle",
            checkTitle: flashMaskSettingsCheckTitle(retry: false, isChinese: isChinese),
            checkEnabled: true,
            resultTitle: nil,
            resultBody: nil,
            storeTitle: nil,
            storeIsPrimary: false
        )
    }
    switch outcome {
    case let .available(_, storeVersion, notes):
        return FlashMaskSettingsUpdateViewModel(
            kind: "available",
            checkTitle: flashMaskSettingsCheckTitle(retry: false, isChinese: isChinese),
            checkEnabled: true,
            resultTitle: isChinese ? "发现新版本 \(storeVersion)" : "Version \(storeVersion) available",
            resultBody: notes,
            storeTitle: isChinese ? "前往 App Store" : "Go to the App Store",
            storeIsPrimary: true
        )
    case .upToDate:
        return FlashMaskSettingsUpdateViewModel(
            kind: "latest",
            checkTitle: flashMaskSettingsCheckTitle(retry: false, isChinese: isChinese),
            checkEnabled: true,
            resultTitle: isChinese ? "已是最新版本" : "You’re up to date",
            resultBody: nil,
            storeTitle: nil,
            storeIsPrimary: false
        )
    case let .incompatible(storeVersion, minimumOS):
        return FlashMaskSettingsUpdateViewModel(
            kind: "incompatible",
            checkTitle: flashMaskSettingsCheckTitle(retry: false, isChinese: isChinese),
            checkEnabled: true,
            resultTitle: isChinese ? "版本 \(storeVersion) 需要 macOS \(minimumOS) 或更高版本。" : "Version \(storeVersion) requires macOS \(minimumOS) or later.",
            resultBody: isChinese ? "请先更新 macOS，再检查 App 更新。" : "Update macOS, then check for app updates.",
            storeTitle: nil,
            storeIsPrimary: false
        )
    case let .failed(reason):
        if reason == .storefrontUnknown {
            return FlashMaskSettingsUpdateViewModel(
                kind: "region",
                checkTitle: flashMaskSettingsCheckTitle(retry: true, isChinese: isChinese),
                checkEnabled: true,
                resultTitle: flashMaskUpdateFailureCopy(reason, isChinese: isChinese),
                resultBody: nil,
                storeTitle: isChinese ? "在 App Store 中查看" : "View in App Store",
                storeIsPrimary: false
            )
        }
        return FlashMaskSettingsUpdateViewModel(
            kind: "failed",
            checkTitle: flashMaskSettingsCheckTitle(retry: true, isChinese: isChinese),
            checkEnabled: true,
            resultTitle: flashMaskUpdateFailureCopy(reason, isChinese: isChinese),
            resultBody: nil,
            storeTitle: nil,
            storeIsPrimary: false
        )
    }
}

final class FlashMaskUpdateChecker {
    var storefrontProvider: FlashMaskStorefrontProvider
    var localVersionProvider: () -> String?
    var operatingSystemVersionProvider: () -> OperatingSystemVersion
    var fetcher: FlashMaskUpdateFetcher
    let timeout: TimeInterval
    private var completions: [(FlashMaskUpdateOutcome, String?) -> Void] = []
    private var checkEpoch: UInt64 = 0
    private(set) var isInFlight = false
    private(set) var lastLookupURL: URL?

    init(
        storefrontProvider: @escaping FlashMaskStorefrontProvider = flashMaskRequestStorefrontCountryCode,
        localVersionProvider: @escaping () -> String? = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        },
        operatingSystemVersionProvider: @escaping () -> OperatingSystemVersion = {
            ProcessInfo.processInfo.operatingSystemVersion
        },
        fetcher: @escaping FlashMaskUpdateFetcher = flashMaskDefaultUpdateFetcher,
        timeout: TimeInterval = flashMaskUpdateCheckTimeout
    ) {
        self.storefrontProvider = storefrontProvider
        self.localVersionProvider = localVersionProvider
        self.operatingSystemVersionProvider = operatingSystemVersionProvider
        self.fetcher = fetcher
        self.timeout = timeout
    }

    func check(completion: @escaping (FlashMaskUpdateOutcome, String?) -> Void) {
        completions.append(completion)
        guard !isInFlight else { return }
        isInFlight = true
        start()
    }

    private func start() {
        lastLookupURL = nil
        checkEpoch += 1
        let epoch = checkEpoch
        let started = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self, self.checkEpoch == epoch, self.isInFlight else { return }
            self.finish(.failed(.timeout), country: nil)
        }
        storefrontProvider { [weak self] storefront in
            guard let self, self.checkEpoch == epoch, self.isInFlight else { return }
            guard let storefront,
                  let country = flashMaskLookupCountryCode(storefrontCountryCode: storefront),
                  let url = flashMaskLookupURL(countryCode: country) else {
                self.finish(.failed(.storefrontUnknown), country: nil)
                return
            }
            self.lastLookupURL = url
            let remaining = max(0.1, self.timeout - Date().timeIntervalSince(started))
            self.fetcher(url, remaining) { [weak self] result in
                guard let self, self.checkEpoch == epoch, self.isInFlight else { return }
                self.handleFetch(result, country: country)
            }
        }
    }

    private func handleFetch(_ result: FlashMaskUpdateFetchResult, country: String) {
        switch result {
        case .timeout:
            finish(.failed(.timeout), country: country)
        case .network:
            finish(.failed(.network), country: country)
        case let .success(status, body):
            if status == 429 {
                finish(.failed(.rateLimited), country: country)
                return
            }
            guard (200..<300).contains(status) else {
                finish(.failed(.invalidResponse), country: country)
                return
            }
            switch flashMaskParseLookup(body) {
            case let .failure(reason):
                finish(.failed(reason), country: country)
            case let .success(app):
                guard let local = localVersionProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !local.isEmpty else {
                    finish(.failed(.invalidVersion), country: country)
                    return
                }
                finish(
                    flashMaskEvaluateUpdate(
                        localVersion: local,
                        storeVersion: app.version,
                        notes: app.releaseNotes,
                        minimumOsVersion: app.minimumOsVersion,
                        currentOS: operatingSystemVersionProvider()
                    ),
                    country: country
                )
            }
        }
    }

    private func finish(_ outcome: FlashMaskUpdateOutcome, country: String?) {
        guard isInFlight else { return }
        checkEpoch += 1
        let callbacks = completions
        completions = []
        isInFlight = false
        let deliver = { callbacks.forEach { $0(outcome, country) } }
        if Thread.isMainThread {
            deliver()
        } else {
            DispatchQueue.main.async(execute: deliver)
        }
    }
}

func flashMaskAllowsNavigation(_ url: URL?) -> Bool {
    guard let scheme = url?.scheme?.lowercased() else { return true }
    return ["file", "about", "blob", "data", "flashmask-local"].contains(scheme)
}

func flashMaskNavigationPolicy(_ url: URL?, shouldPerformDownload: Bool) -> WKNavigationActionPolicy {
    guard flashMaskAllowsNavigation(url) else { return .cancel }
    return shouldPerformDownload ? .download : .allow
}

private let flashMaskLanguagePreferenceKey = "FlashMaskLanguage"

private func resolvedFlashMaskLanguage() -> String {
    let preference = UserDefaults.standard.string(forKey: flashMaskLanguagePreferenceKey) ?? "system"
    if preference == "zh" || preference == "en" { return preference }
    return Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? "zh" : "en"
}

func flashMaskSystemPreferredLanguages(defaults: UserDefaults = .standard) -> [String] {
    if let global = defaults.persistentDomain(forName: UserDefaults.globalDomain)?["AppleLanguages"] as? [String],
       global.isEmpty == false {
        return global
    }
    return Locale.preferredLanguages
}

func flashMaskMatchingPanelLanguage(_ requested: [String], bundleLocalizations: [String]) -> String {
    let available = Set(bundleLocalizations.map { $0.lowercased() })
    let hasChinese = available.contains { $0 == "zh-hans" || $0 == "zh" || $0.hasPrefix("zh-hans") }
    let hasEnglish = available.contains { $0 == "en" || $0 == "base" || $0.hasPrefix("en") }
    for item in requested {
        let lower = item.lowercased()
        if lower.hasPrefix("zh"), hasChinese { return "zh" }
        if lower.hasPrefix("en"), hasEnglish { return "en" }
    }
    return hasEnglish || !hasChinese ? "en" : "zh"
}

func flashMaskBundlePanelLanguage(_ bundle: Bundle = .main) -> String {
    flashMaskMatchingPanelLanguage(bundle.preferredLocalizations, bundleLocalizations: bundle.localizations)
}

func flashMaskSystemPanelLanguage(
    systemLanguages: [String] = flashMaskSystemPreferredLanguages(),
    bundleLocalizations: [String] = Bundle.main.localizations
) -> String {
    flashMaskMatchingPanelLanguage(systemLanguages, bundleLocalizations: bundleLocalizations)
}

func flashMaskPersistLanguagePreference(
    _ preference: String,
    defaults: UserDefaults = .standard
) {
    let supported = ["system", "zh", "en"].contains(preference) ? preference : "system"
    defaults.set(supported, forKey: flashMaskLanguagePreferenceKey)
}

func flashMaskOwnedFilePanelPrompt(isOpen: Bool, language: String) -> String {
    if isOpen { return language == "zh" ? "打开" : "Open" }
    return language == "zh" ? "保存" : "Save"
}

func flashMaskApplyOwnedFilePanelStrings(_ panel: NSSavePanel, isOpen: Bool, language: String = flashMaskBundlePanelLanguage()) {
    panel.prompt = flashMaskOwnedFilePanelPrompt(isOpen: isOpen, language: language)
}

final class SecurityScopedFileAccess {
    let url: URL
    private let lock = NSLock()
    private var stopsRemaining: Int
    private let stopAccess: (URL) -> Void

    init(
        url: URL,
        hasImplicitScope: Bool = false,
        startAccess: @escaping (URL) -> Bool = { $0.startAccessingSecurityScopedResource() },
        stopAccess: @escaping (URL) -> Void = { $0.stopAccessingSecurityScopedResource() }
    ) {
        self.url = url
        let accessStarted = startAccess(url)
        // NSOpenPanel and Finder hand off one implicit scope; an explicit
        // successful start adds a second scope that needs its own stop.
        self.stopsRemaining = (hasImplicitScope ? 1 : 0) + (accessStarted ? 1 : 0)
        self.stopAccess = stopAccess
    }

    func release() {
        lock.lock()
        let stopCount = stopsRemaining
        stopsRemaining = 0
        lock.unlock()
        for _ in 0..<stopCount { stopAccess(url) }
    }

    deinit {
        release()
    }
}

private struct NativeImportTask {
    let nonce: String
    let url: URL
    let pathDelay: TimeInterval
    let access: SecurityScopedFileAccess
}

struct MaskDownloadDestination {
    let temporary: URL
    let final: URL
    let replaceExisting: Bool
    let temporaryDirectory: URL?
    let access: SecurityScopedFileAccess?

    init(
        temporary: URL,
        final: URL,
        replaceExisting: Bool,
        temporaryDirectory: URL? = nil,
        access: SecurityScopedFileAccess? = nil
    ) {
        self.temporary = temporary
        self.final = final
        self.replaceExisting = replaceExisting
        self.temporaryDirectory = temporaryDirectory
        self.access = access
    }
}

struct MaskDownloadTemporary {
    let url: URL
    let directory: URL
}

func finishMaskDownload(_ destination: MaskDownloadDestination, fileManager: FileManager = .default) throws {
    defer { destination.access?.release() }
    if destination.replaceExisting {
        _ = try fileManager.replaceItemAt(destination.final, withItemAt: destination.temporary)
    } else {
        try fileManager.moveItem(at: destination.temporary, to: destination.final)
    }
}

func makeMaskDownloadTemporaryURL(fileManager: FileManager = .default) -> URL {
    fileManager.temporaryDirectory.appendingPathComponent("flash-mask-\(UUID().uuidString).download")
}

func makeMaskDownloadTemporaryURL(
    appropriateFor finalURL: URL,
    fileManager: FileManager = .default
) throws -> MaskDownloadTemporary {
    let directory = try fileManager.url(
        for: .itemReplacementDirectory,
        in: .userDomainMask,
        appropriateFor: finalURL,
        create: true
    )
    return MaskDownloadTemporary(
        url: directory.appendingPathComponent("flash-mask-\(UUID().uuidString).download"),
        directory: directory
    )
}

func cleanupMaskDownloadTemporary(_ destination: MaskDownloadDestination, fileManager: FileManager = .default) {
    try? fileManager.removeItem(at: destination.temporary)
    if let directory = destination.temporaryDirectory {
        try? fileManager.removeItem(at: directory)
    }
    destination.access?.release()
}

func flashMaskFileIsReadable(_ url: URL) -> Bool {
    guard url.isFileURL else { return false }
    do {
        let file = try FileHandle(forReadingFrom: url)
        try file.close()
        return true
    } catch {
        return false
    }
}

func maskDownloadDestination(response: NSApplication.ModalResponse, url: URL?) -> URL? {
    response == .OK ? url : nil
}

enum MaskDownloadFailureAction {
    case deferUntilDestinationDecision
    case ignore
    case notify(MaskDownloadDestination?)
}

enum MaskDownloadDestinationAction {
    case start(MaskDownloadDestination)
    case stop(Error?)
}

final class MaskDownloadStateMachine {
    private enum State {
        case choosingDestination
        case downloading(MaskDownloadDestination)
        case cancelled
        case failedBeforeDestination(Error)
    }

    private var states: [ObjectIdentifier: State] = [:]

    func begin(_ identifier: ObjectIdentifier) {
        states[identifier] = .choosingDestination
    }

    func resolveDestination(_ identifier: ObjectIdentifier, destination: MaskDownloadDestination?) -> MaskDownloadDestinationAction {
        guard let state = states[identifier] else { return .stop(nil) }
        switch state {
        case .choosingDestination:
            guard let destination else {
                states[identifier] = .cancelled
                return .stop(nil)
            }
            states[identifier] = .downloading(destination)
            return .start(destination)
        case .failedBeforeDestination(let error):
            states.removeValue(forKey: identifier)
            return .stop(error)
        case .cancelled, .downloading:
            return .stop(nil)
        }
    }

    func finish(_ identifier: ObjectIdentifier) -> MaskDownloadDestination? {
        guard case .downloading(let destination) = states.removeValue(forKey: identifier) else { return nil }
        return destination
    }

    func abort(_ identifier: ObjectIdentifier) {
        states.removeValue(forKey: identifier)
    }

    func fail(_ identifier: ObjectIdentifier, error: Error) -> MaskDownloadFailureAction {
        guard let state = states[identifier] else { return .ignore }
        switch state {
        case .choosingDestination:
            states[identifier] = .failedBeforeDestination(error)
            return .deferUntilDestinationDecision
        case .downloading(let destination):
            states.removeValue(forKey: identifier)
            return .notify(destination)
        case .cancelled:
            states.removeValue(forKey: identifier)
            return .ignore
        case .failedBeforeDestination:
            return .deferUntilDestinationDecision
        }
    }
}

struct LocalImageTaskToken: Equatable {
    fileprivate let generation: UInt64
}

final class LocalImageTaskRegistry {
    private struct Entry {
        let token: LocalImageTaskToken
        let workItem: DispatchWorkItem
    }

    private let lock = NSLock()
    private var nextGeneration: UInt64 = 0
    private var entries: [ObjectIdentifier: Entry] = [:]

    func register(_ identifier: ObjectIdentifier, workItem: DispatchWorkItem) -> LocalImageTaskToken {
        lock.lock()
        nextGeneration += 1
        let token = LocalImageTaskToken(generation: nextGeneration)
        entries[identifier] = Entry(token: token, workItem: workItem)
        lock.unlock()
        return token
    }

    func isActive(_ identifier: ObjectIdentifier, token: LocalImageTaskToken) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return entries[identifier]?.token == token
    }

    @discardableResult
    func cancel(_ identifier: ObjectIdentifier, token: LocalImageTaskToken) -> Bool {
        lock.lock()
        guard let entry = entries[identifier], entry.token == token else {
            lock.unlock()
            return false
        }
        entries.removeValue(forKey: identifier)
        lock.unlock()
        entry.workItem.cancel()
        return true
    }

    @discardableResult
    func complete(_ identifier: ObjectIdentifier, token: LocalImageTaskToken) -> Bool {
        lock.lock()
        guard let entry = entries[identifier], entry.token == token else {
            lock.unlock()
            return false
        }
        entries.removeValue(forKey: identifier)
        lock.unlock()
        return true
    }

    @discardableResult
    func cancelCurrent(_ identifier: ObjectIdentifier) -> Bool {
        lock.lock()
        guard let entry = entries.removeValue(forKey: identifier) else {
            lock.unlock()
            return false
        }
        lock.unlock()
        entry.workItem.cancel()
        return true
    }
}

private let localImageReadChunkSize = 256 * 1024

func collectLocalImageData(
    chunkSize: Int = localImageReadChunkSize,
    isActive: () -> Bool,
    readChunk: (Int) throws -> Data?
) throws -> Data? {
    precondition(chunkSize > 0)
    var result = Data()
    while isActive() {
        guard let chunk = try readChunk(chunkSize), !chunk.isEmpty else {
            return isActive() ? result : nil
        }
        guard isActive() else { return nil }
        result.append(chunk)
    }
    return nil
}

private final class LocalImageSchemeHandler: NSObject, WKURLSchemeHandler {
    var sources: [String: URL] = [:]
    private let taskRegistry = LocalImageTaskRegistry()

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url,
              let nonce = requestURL.host,
              let source = sources[nonce] else {
            urlSchemeTask.didFailWithError(NSError(domain: "FlashMask", code: 1, userInfo: nil))
            return
        }
        let taskIdentifier = ObjectIdentifier(urlSchemeTask)
        let extensionName = source.pathExtension.lowercased()
        let mimeType = extensionName == "png" ? "image/png" : extensionName == "webp" ? "image/webp" : "image/jpeg"
        var taskToken: LocalImageTaskToken?
        let workItem = DispatchWorkItem { [weak self, weak urlSchemeTask] in
            guard let taskToken, let self, self.taskRegistry.isActive(taskIdentifier, token: taskToken) else { return }
            let result: Result<Data?, Error> = Result {
                let file = try FileHandle(forReadingFrom: source)
                defer { try? file.close() }
                return try collectLocalImageData(isActive: { [weak self] in
                    self?.taskRegistry.isActive(taskIdentifier, token: taskToken) == true
                }, readChunk: { try file.read(upToCount: $0) })
            }
            guard self.taskRegistry.isActive(taskIdentifier, token: taskToken) else { return }
            DispatchQueue.main.async { [weak self, weak urlSchemeTask] in
                guard let self, self.taskRegistry.complete(taskIdentifier, token: taskToken) else { return }
                guard let urlSchemeTask else { return }
                switch result {
                case .success(let data?):
                    let response = URLResponse(url: requestURL, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: nil)
                    urlSchemeTask.didReceive(response)
                    urlSchemeTask.didReceive(data)
                    urlSchemeTask.didFinish()
                case .success(nil):
                    return
                case .failure(let error):
                    urlSchemeTask.didFailWithError(error)
                }
            }
        }
        taskToken = taskRegistry.register(taskIdentifier, workItem: workItem)
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        taskRegistry.cancelCurrent(ObjectIdentifier(urlSchemeTask))
    }
}

private final class ImportWebView: WKWebView {
    var onDroppedURL: ((URL) -> Void)?
    var onDragHighlight: ((Bool) -> Void)?

    override init(frame: NSRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let accepted = supportedImageURL(from: sender) != nil
        onDragHighlight?(accepted)
        return accepted ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let accepted = supportedImageURL(from: sender) != nil
        onDragHighlight?(accepted)
        return accepted ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragHighlight?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { onDragHighlight?(false) }
        guard let url = supportedImageURL(from: sender) else { return false }
        onDroppedURL?(url)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        onDragHighlight?(false)
    }

    private func supportedImageURL(from sender: NSDraggingInfo) -> URL? {
        flashMaskSupportedImageURL(from: sender.draggingPasteboard)
    }
}

func flashMaskSupportedImageURL(from pasteboard: NSPasteboard) -> URL? {
    guard let value = pasteboard.readObjects(
        forClasses: [NSURL.self],
        options: [.urlReadingFileURLsOnly: true]
    )?.first as? NSURL else { return nil }
    let url = value as URL
    guard url.isFileURL,
          ["png", "jpg", "jpeg", "webp"].contains(url.pathExtension.lowercased()) else { return nil }
    return url
}

let flashMaskSupportedPasteFileExtensions: Set<String> = ["png", "jpg", "jpeg", "webp"]
private let flashMaskRasterPasteTypes: [NSPasteboard.PasteboardType] = [
    .png,
    .tiff,
    NSPasteboard.PasteboardType("public.jpeg")
]

enum FlashMaskPasteContent: Equatable {
    case none
    case multipleImages
    case file(URL)
    case raster(Data)
}

struct FlashMaskDecodedRaster: Equatable {
    let pngData: Data
    let pixelWidth: Int
    let pixelHeight: Int
    let hasAlpha: Bool
}

func flashMaskNeedsReplaceConfirmation(regionCount: Int, overallPrompt: String, regionPrompts: [String]) -> Bool {
    if regionCount > 0 { return true }
    if !overallPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
    return regionPrompts.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

func flashMaskPasteUsesSystemHandler(
    isMainWindow: Bool,
    hasModalSession: Bool,
    nativeTextCanPaste: Bool,
    pageHasEditableElement: Bool,
    hasMarkedText: Bool
) -> Bool {
    !isMainWindow || hasModalSession || nativeTextCanPaste || pageHasEditableElement || hasMarkedText
}

func flashMaskHasMarkedText(_ view: NSView) -> Bool {
    (view as? NSTextInputClient)?.hasMarkedText() == true
}

func flashMaskNativeTextCanPaste(firstResponder: NSResponder?, pageView: NSView?) -> Bool {
    var responder = firstResponder
    while let current = responder {
        let isPageResponder = pageView.map {
            current === $0 || (current as? NSView)?.isDescendant(of: $0) == true
        } ?? false
        if !isPageResponder {
            if let textView = current as? NSTextView, textView.isEditable { return true }
            if current is NSTextField { return true }
        }
        responder = current.nextResponder
    }
    return false
}

func flashMaskFileURL(from item: NSPasteboardItem) -> URL? {
    if let url = item.propertyList(forType: .fileURL) as? URL, url.isFileURL {
        return url.standardizedFileURL
    }
    if let url = item.propertyList(forType: .fileURL) as? NSURL, url.isFileURL {
        return (url as URL).standardizedFileURL
    }
    guard let data = item.data(forType: .fileURL),
          let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters)),
          let url = URL(string: text), url.isFileURL else { return nil }
    return url.standardizedFileURL
}

func flashMaskRasterData(from item: NSPasteboardItem) -> Data? {
    for type in flashMaskRasterPasteTypes {
        if let data = item.data(forType: type), !data.isEmpty { return data }
    }
    return nil
}

func flashMaskInspectPasteboard(_ pasteboard: NSPasteboard) -> FlashMaskPasteContent {
    var files: [URL] = []
    var seenPaths = Set<String>()
    var rasters: [Data] = []
    for item in pasteboard.pasteboardItems ?? [] {
        if let url = flashMaskFileURL(from: item), url.isFileURL {
            let ext = url.pathExtension.lowercased()
            if flashMaskSupportedPasteFileExtensions.contains(ext), seenPaths.insert(url.path).inserted {
                files.append(url)
            }
            continue
        }
        if let data = flashMaskRasterData(from: item) {
            rasters.append(data)
        }
    }
    let imageCount = files.count + rasters.count
    if imageCount == 0 { return .none }
    if imageCount > 1 { return .multipleImages }
    if let url = files.first { return .file(url) }
    if let data = rasters.first { return .raster(data) }
    return .none
}

func flashMaskPNGData(from image: CGImage) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
        return nil
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return data as Data
}

func flashMaskImageHasAlpha(_ image: CGImage) -> Bool {
    switch image.alphaInfo {
    case .none, .noneSkipLast, .noneSkipFirst: return false
    default: return true
    }
}

func flashMaskDecodeRasterData(_ data: Data) -> FlashMaskDecodedRaster? {
    guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
          CGImageSourceGetCount(source) > 0 else { return nil }
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    let storedWidth = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
    let storedHeight = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
    guard storedWidth > 0, storedHeight > 0 else { return nil }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: max(storedWidth, storedHeight),
        kCGImageSourceShouldCacheImmediately: false
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
          image.width > 0, image.height > 0,
          let png = flashMaskPNGData(from: image) else { return nil }
    return FlashMaskDecodedRaster(
        pngData: png,
        pixelWidth: image.width,
        pixelHeight: image.height,
        hasAlpha: flashMaskImageHasAlpha(image)
    )
}

func flashMaskDecodePNGFile(_ url: URL) -> FlashMaskDecodedRaster? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return flashMaskDecodeRasterData(data)
}

func flashMaskScreenshotDirectoryURL(fileManager: FileManager = .default) -> URL? {
    fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first?
        .appendingPathComponent("Flash Mask", isDirectory: true)
}

func flashMaskScreenshotFileName(now: Date = Date(), random: String = UUID().uuidString) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
    let token = String(random.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
    return "Flash Mask \(formatter.string(from: now)) \(token).png"
}

func flashMaskSaveScreenshotPNG(
    _ decoded: FlashMaskDecodedRaster,
    directory: URL,
    fileManager: FileManager = .default,
    makeName: () -> String = { flashMaskScreenshotFileName() }
) throws -> URL {
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    var lastError: Error = NSError(domain: "FlashMask", code: 4, userInfo: nil)
    for _ in 0..<8 {
        let finalURL = directory.appendingPathComponent(makeName())
        if fileManager.fileExists(atPath: finalURL.path) { continue }
        let temporary: MaskDownloadTemporary
        do {
            temporary = try makeMaskDownloadTemporaryURL(appropriateFor: finalURL, fileManager: fileManager)
        } catch {
            lastError = error
            continue
        }
        let destination = MaskDownloadDestination(
            temporary: temporary.url,
            final: finalURL,
            replaceExisting: false,
            temporaryDirectory: temporary.directory
        )
        do {
            try decoded.pngData.write(to: temporary.url, options: .withoutOverwriting)
            try finishMaskDownload(destination, fileManager: fileManager)
            cleanupMaskDownloadTemporary(destination, fileManager: fileManager)
            guard flashMaskFileIsReadable(finalURL),
                  let verified = flashMaskDecodePNGFile(finalURL),
                  verified.pixelWidth == decoded.pixelWidth,
                  verified.pixelHeight == decoded.pixelHeight else {
                try? fileManager.removeItem(at: finalURL)
                throw NSError(domain: "FlashMask", code: 5, userInfo: nil)
            }
            return finalURL
        } catch {
            cleanupMaskDownloadTemporary(destination, fileManager: fileManager)
            try? fileManager.removeItem(at: finalURL)
            lastError = error
        }
    }
    throw lastError
}

func flashMaskDeleteIfExists(_ url: URL, fileManager: FileManager = .default) {
    try? fileManager.removeItem(at: url)
}

final class FlashMaskController: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate, WKDownloadDelegate {
    let webView: WKWebView
    var onPageReady: (() -> Void)?
    var onLanguagePreferenceChange: (() -> Void)?
    var confirmReplaceHandler: ((Bool) -> Bool)?
    var chooseAlternateSaveHandler: (() -> URL?)?
    var pasteNoticeHandler: ((String, String) -> Void)?
    var openURLHandler: ((URL) -> Bool)?
    var screenshotDirectoryOverride: URL?

    private let pageURL: URL
    private let imageSchemeHandler = LocalImageSchemeHandler()
    private var imports: [String: NativeImportTask] = [:]
    private var pageReady = false
    private var pendingDroppedFile: (url: URL, access: SecurityScopedFileAccess)?
    private var showingFailurePage = false
    private let downloadStates = MaskDownloadStateMachine()
    private var createdScreenshotByNonce: [String: URL] = [:]
    private var pendingCreatedScreenshot: URL?
    private var pathRequestedNonces = Set<String>()
    private var pasteGeneration: UInt64 = 0

    init(pageURL: URL) {
        self.pageURL = pageURL
        let contentController = WKUserContentController()
        let initialLanguage = resolvedFlashMaskLanguage()
        contentController.addUserScript(WKUserScript(
            source: "window.__flashMaskInitialLanguage = '\(initialLanguage)';",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.setURLSchemeHandler(imageSchemeHandler, forURLScheme: "flashmask-local")
        self.webView = ImportWebView(frame: .zero, configuration: configuration)
        super.init()
        contentController.add(self, name: "flashMaskBridge")
        webView.navigationDelegate = self
        webView.uiDelegate = self
        (webView as? ImportWebView)?.onDroppedURL = { [weak self] url in
            guard let self else { return }
            let access = SecurityScopedFileAccess(url: url, hasImplicitScope: true)
            if self.pageReady {
                _ = self.beginImport(url, origin: "drag-drop", pathDelay: 0, access: access)
            } else {
                self.pendingDroppedFile = (url, access)
            }
        }
        (webView as? ImportWebView)?.onDragHighlight = { [weak self] active in
            self?.setNativeDragHighlight(active)
        }
    }

    func load() {
        pageReady = false
        showingFailurePage = false
        webView.loadFileURL(pageURL, allowingReadAccessTo: pageURL.deletingLastPathComponent())
    }

    @discardableResult
    func importFromSelection(_ url: URL, pathDelay: TimeInterval = 0, hasImplicitScope: Bool = false) -> String {
        beginImport(url, origin: "file-selection", pathDelay: pathDelay, hasImplicitScope: hasImplicitScope)
    }

    @discardableResult
    func importFromDrop(_ url: URL, pathDelay: TimeInterval = 0) -> String {
        beginImport(url, origin: "drag-drop", pathDelay: pathDelay, hasImplicitScope: false)
    }

    func performPaste(_ sender: Any?) {
        let keyWindow = NSApp.keyWindow
        let isMainWindow = keyWindow === webView.window
        let hasModalSession = NSApp.modalWindow != nil
        let nativeTextCanPaste = flashMaskNativeTextCanPaste(firstResponder: keyWindow?.firstResponder, pageView: webView)
        let hasMarkedText = flashMaskHasMarkedText(webView)
        if flashMaskPasteUsesSystemHandler(
            isMainWindow: isMainWindow,
            hasModalSession: hasModalSession,
            nativeTextCanPaste: nativeTextCanPaste,
            pageHasEditableElement: false,
            hasMarkedText: hasMarkedText
        ) {
            NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: sender)
            return
        }
        webView.evaluateJavaScript(flashMaskTextUndoPredicate) { [weak self] value, _ in
            guard let self else { return }
            let pageHasEditableElement = value as? Bool == true
            let stillMain = NSApp.keyWindow === self.webView.window
            let stillModal = NSApp.modalWindow != nil
            let stillNative = flashMaskNativeTextCanPaste(
                firstResponder: NSApp.keyWindow?.firstResponder,
                pageView: self.webView
            )
            let stillMarked = flashMaskHasMarkedText(self.webView)
            if flashMaskPasteUsesSystemHandler(
                isMainWindow: stillMain,
                hasModalSession: stillModal,
                nativeTextCanPaste: stillNative,
                pageHasEditableElement: pageHasEditableElement,
                hasMarkedText: stillMarked
            ) {
                NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: sender)
                return
            }
            self.importFromPasteboard(NSPasteboard.general, sender: sender)
        }
    }

    func importFromPasteboard(_ pasteboard: NSPasteboard, sender: Any? = nil) {
        guard pageReady else { return }
        switch flashMaskInspectPasteboard(pasteboard) {
        case .none:
            NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: sender)
        case .multipleImages:
            _ = invalidateInFlightPaste()
            presentPasteNotice(
                title: resolvedFlashMaskLanguage() == "zh" ? "一次只支持一张图片" : "Paste one image at a time",
                body: resolvedFlashMaskLanguage() == "zh" ? "当前圈选和说明已保留。" : "Your current outlines and notes are unchanged."
            )
        case .file(let url):
            let generation = invalidateInFlightPaste()
            confirmReplaceIfNeeded { [weak self] confirmed in
                guard let self, confirmed, self.pasteGeneration == generation else { return }
                let access = SecurityScopedFileAccess(url: url, hasImplicitScope: false)
                guard flashMaskFileIsReadable(url), flashMaskDecodePNGFile(url) != nil else {
                    access.release()
                    self.presentPasteNotice(
                        title: resolvedFlashMaskLanguage() == "zh" ? "图片无法解码" : "We couldn’t open this image",
                        body: resolvedFlashMaskLanguage() == "zh" ? "当前圈选和说明已保留。" : "Your current outlines and notes are unchanged."
                    )
                    return
                }
                _ = self.beginImport(
                    url,
                    origin: "clipboard-paste",
                    pathDelay: 0,
                    access: access,
                    skipReplaceConfirmation: true
                )
            }
        case .raster(let data):
            importPastedRaster(data)
        }
    }

    func openScreenshotFolder() {
        let directory = screenshotDirectoryOverride ?? flashMaskScreenshotDirectoryURL()
        guard let directory else {
            presentPasteNotice(
                title: resolvedFlashMaskLanguage() == "zh" ? "无法打开保存文件夹" : "Couldn’t open the saved-images folder",
                body: resolvedFlashMaskLanguage() == "zh" ? "系统下载目录不可用。" : "The Downloads folder is unavailable."
            )
            return
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            guard NSWorkspace.shared.open(directory) else {
                presentPasteNotice(
                    title: resolvedFlashMaskLanguage() == "zh" ? "无法打开保存文件夹" : "Couldn’t open the saved-images folder",
                    body: resolvedFlashMaskLanguage() == "zh" ? "系统未能打开该文件夹。" : "The folder could not be opened."
                )
                return
            }
        } catch {
            presentPasteNotice(
                title: resolvedFlashMaskLanguage() == "zh" ? "无法打开保存文件夹" : "Couldn’t open the saved-images folder",
                body: error.localizedDescription
            )
        }
    }

    func snapshot(_ completion: @escaping (Result<[String: Any], Error>) -> Void) {
        evaluateObject("window.FlashMaskP0.snapshot()", completion: completion)
    }

    func copyResult(_ completion: @escaping (Result<[String: Any], Error>) -> Void) {
        evaluateObject("window.FlashMaskP0.copyResult()", completion: completion)
    }

    func clickCopy() {
        webView.evaluateJavaScript("document.querySelector('#copy-json').click()")
    }

    func setViewport(zoom: Double, x: Double, y: Double, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        evaluateObject("window.FlashMaskP0.setViewport({zoom: \(zoom), x: \(x), y: \(y)})", completion: completion)
    }

    func setLanguagePreference(_ preference: String, persist: Bool = true, completion: (() -> Void)? = nil) {
        let supportedPreference = ["system", "zh", "en"].contains(preference) ? preference : "system"
        if persist { flashMaskPersistLanguagePreference(supportedPreference) }
        let language: String
        if supportedPreference == "system" {
            language = Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? "zh" : "en"
        } else {
            language = supportedPreference
        }
        let finish = {
            completion?()
        }
        guard let data = try? JSONSerialization.data(withJSONObject: language, options: .fragmentsAllowed),
              let json = String(data: data, encoding: .utf8) else {
            finish()
            return
        }
        webView.evaluateJavaScript("window.FlashMaskP0.setLanguage(\(json))") { _, _ in finish() }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !showingFailurePage else { return }
        probePageReadiness(attemptsRemaining: 20)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if !showingFailurePage { pageReady = false }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        renderPageLoadFailure()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        renderPageLoadFailure()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        renderPageLoadFailure()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(flashMaskNavigationPolicy(
            navigationAction.request.url,
            shouldPerformDownload: navigationAction.shouldPerformDownload
        ))
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        downloadStates.begin(ObjectIdentifier(download))
        download.delegate = self
    }

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = suggestedFilename
        flashMaskApplyOwnedFilePanelStrings(panel, isOpen: false)
        panel.begin { [weak self] result in
            guard let self else {
                if result == .OK, let url = panel.url {
                    SecurityScopedFileAccess(url: url, hasImplicitScope: true).release()
                }
                completionHandler(nil)
                return
            }
            let identifier = ObjectIdentifier(download)
            var destination: MaskDownloadDestination?
            if let finalURL = maskDownloadDestination(response: result, url: panel.url) {
                let access = SecurityScopedFileAccess(url: finalURL, hasImplicitScope: true)
                do {
                    let temporary = try makeMaskDownloadTemporaryURL(appropriateFor: finalURL)
                    destination = MaskDownloadDestination(
                        temporary: temporary.url,
                        final: finalURL,
                        replaceExisting: FileManager.default.fileExists(atPath: finalURL.path),
                        temporaryDirectory: temporary.directory,
                        access: access
                    )
                } catch {
                    self.downloadStates.abort(identifier)
                    access.release()
                    completionHandler(nil)
                    self.showDownloadError(error)
                    return
                }
            }
            switch self.downloadStates.resolveDestination(identifier, destination: destination) {
            case .start(let destination):
                completionHandler(destination.temporary)
            case .stop(let error):
                completionHandler(nil)
                if let destination { cleanupMaskDownloadTemporary(destination) }
                if let error { self.showDownloadError(error) }
            }
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let destination = downloadStates.finish(ObjectIdentifier(download)) else { return }
        do {
            try finishMaskDownload(destination)
            cleanupMaskDownloadTemporary(destination)
        } catch {
            cleanupMaskDownloadTemporary(destination)
            showDownloadError(error)
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        let identifier = ObjectIdentifier(download)
        switch downloadStates.fail(identifier, error: error) {
        case .deferUntilDestinationDecision, .ignore:
            return
        case .notify(let destination):
            if let destination {
                cleanupMaskDownloadTemporary(destination)
            }
            showDownloadError(error)
        }
    }

    func performUndo(_ sender: Any?) {
        let keyWindow = NSApp.keyWindow
        let isMainWindow = keyWindow === webView.window
        let nativeResponderCanUndo = flashMaskNativeUndoResponderCanUndo(
            firstResponder: keyWindow?.firstResponder,
            pageView: webView
        )
        guard isMainWindow, !nativeResponderCanUndo else {
            // `undo:` deliberately differs from this menu item's `performUndo:` target.
            NSApp.sendAction(Selector(("undo:")), to: nil, from: sender)
            return
        }

        webView.evaluateJavaScript(flashMaskTextUndoPredicate) { [weak self] value, _ in
            guard let self else { return }
            let decision = flashMaskUndoDecision(
                isMainWindow: NSApp.keyWindow === self.webView.window,
                nativeResponderCanUndo: flashMaskNativeUndoResponderCanUndo(
                    firstResponder: NSApp.keyWindow?.firstResponder,
                    pageView: self.webView
                ),
                pageHasEditableElement: value as? Bool == true
            )
            switch decision {
            case .nativeResponder, .pageText:
                NSApp.sendAction(Selector(("undo:")), to: nil, from: sender)
            case .pageCanvas:
                self.webView.evaluateJavaScript("window.FlashMaskP0?.undo()")
            }
        }
    }

    private func showDownloadError(_ error: Error) {
        let chinese = resolvedFlashMaskLanguage() == "zh"
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = chinese ? "蒙版保存失败" : "Couldn’t save the mask"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }

    private func probePageReadiness(attemptsRemaining: Int) {
        let probe = "Boolean(window.FlashMaskP0 && typeof window.FlashMaskP0.beginMacImport === 'function' && typeof window.FlashMaskP0.setLanguage === 'function' && typeof window.FlashMaskP0.setNativeDragHighlight === 'function')"
        webView.evaluateJavaScript(probe) { [weak self] value, error in
            guard let self, !self.pageReady else { return }
            if error == nil, value as? Bool == true {
                self.completePageReadiness()
                return
            }
            guard attemptsRemaining > 1 else {
                self.renderPageLoadFailure()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.probePageReadiness(attemptsRemaining: attemptsRemaining - 1)
            }
        }
    }

    private func completePageReadiness() {
        pageReady = true
        let completion = onPageReady
        onPageReady = nil
        setLanguagePreference(UserDefaults.standard.string(forKey: "FlashMaskLanguage") ?? "system", persist: false) {
            completion?()
        }
        if let pending = pendingDroppedFile {
            pendingDroppedFile = nil
            _ = beginImport(pending.url, origin: "drag-drop", pathDelay: 0, access: pending.access)
        }
    }

    private func renderPageLoadFailure() {
        guard !showingFailurePage else { return }
        pageReady = false
        pendingDroppedFile = nil
        if let pending = pendingCreatedScreenshot {
            flashMaskDeleteIfExists(pending)
            pendingCreatedScreenshot = nil
        }
        for nonce in Array(imports.keys) { releaseImport(nonce) }
        showingFailurePage = true
        let message = resolvedFlashMaskLanguage() == "zh" ? "Flash Mask 页面加载失败，请重新打开应用。" : "Flash Mask failed to load. Please reopen the app."
        let escaped = message.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        webView.loadHTMLString("<meta name='color-scheme' content='dark'><body style='margin:0;padding:32px;color:#fff;background:#080c0f;font:16px system-ui'>\(escaped)</body>", baseURL: nil)
    }

    private func setNativeDragHighlight(_ active: Bool) {
        guard pageReady else { return }
        callJavaScript("window.FlashMaskP0.setNativeDragHighlight", object: ["active": active])
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        switch type {
        case "import-release":
            guard let nonce = body["import_nonce"] as? String else { return }
            releaseImport(nonce)
        case "path-request":
            guard let nonce = body["import_nonce"] as? String,
                  let fileName = body["file_name"] as? String,
                  let task = imports[nonce], task.url.lastPathComponent == fileName else { return }
            pathRequestedNonces.insert(nonce)
            createdScreenshotByNonce.removeValue(forKey: nonce)
            DispatchQueue.main.asyncAfter(deadline: .now() + task.pathDelay) { [weak self] in
                self?.returnPath(for: task)
            }
        case "copy-json":
            guard let copyNonce = body["copy_nonce"] as? String,
                  let text = body["text"] as? String else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            callJavaScript("window.FlashMaskP0.acceptNativeCopy", object: [
                "copy_nonce": copyNonce,
                "ok": pasteboard.setString(text, forType: .string)
            ])
        case "language-preference":
            guard let language = body["language"] as? String, ["zh", "en"].contains(language) else { return }
            setLanguagePreference(language) { [weak self] in
                self?.onLanguagePreferenceChange?()
            }
        case "open-external":
            guard let destination = body["destination"] as? String else { return }
            openExternalDestination(destination)
        default:
            return
        }
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg, .webP]
        flashMaskApplyOwnedFilePanelStrings(panel, isOpen: true)
        if panel.runModal() == .OK, let url = panel.url {
            importFromSelection(url, hasImplicitScope: true)
        }
        completionHandler(nil)
    }

    private func beginImport(
        _ url: URL,
        origin: String,
        pathDelay: TimeInterval,
        access: SecurityScopedFileAccess? = nil,
        skipReplaceConfirmation: Bool = false,
        hasImplicitScope: Bool = false
    ) -> String {
        let nonce = UUID().uuidString
        for activeNonce in Array(imports.keys) { releaseImport(activeNonce) }
        let task = NativeImportTask(
            nonce: nonce,
            url: url.standardizedFileURL,
            pathDelay: pathDelay,
            access: access ?? SecurityScopedFileAccess(url: url, hasImplicitScope: hasImplicitScope)
        )
        // ponytail: one active task is sufficient; delayed callbacks retain their task value.
        imports = [nonce: task]
        imageSchemeHandler.sources = [nonce: task.url]
        if let pending = pendingCreatedScreenshot, pending.standardizedFileURL == task.url {
            createdScreenshotByNonce[nonce] = pending
            pendingCreatedScreenshot = nil
        }
        let startPageImport = { [weak self] in
            guard let self, self.imports[nonce] != nil else { return }
            self.callJavaScript("window.FlashMaskP0.beginMacImport", object: [
                "import_nonce": nonce,
                "file_name": task.url.lastPathComponent,
                "image_url": "flashmask-local://\(nonce)/image",
                "origin": origin
            ])
        }
        if skipReplaceConfirmation {
            startPageImport()
        } else {
            confirmReplaceIfNeeded { [weak self] confirmed in
                guard let self, self.imports[nonce] != nil else { return }
                if confirmed {
                    startPageImport()
                } else {
                    self.releaseImport(nonce)
                }
            }
        }
        return nonce
    }

    private func returnPath(for task: NativeImportTask) {
        guard imports[task.nonce] != nil, flashMaskFileIsReadable(task.url) else {
            releaseImport(task.nonce)
            return
        }
        let response: [String: Any] = [
            "import_nonce": task.nonce,
            "file_name": task.url.lastPathComponent,
            "file_path": task.url.path
        ]
        callJavaScript("window.FlashMaskP0.acceptNativePath", object: response) { [weak self] _ in
            self?.releaseImport(task.nonce)
        }
    }

    private func releaseImport(_ nonce: String) {
        guard let task = imports.removeValue(forKey: nonce) else { return }
        imageSchemeHandler.sources.removeValue(forKey: nonce)
        task.access.release()
        if !pathRequestedNonces.contains(nonce), let created = createdScreenshotByNonce.removeValue(forKey: nonce) {
            flashMaskDeleteIfExists(created)
        }
        pathRequestedNonces.remove(nonce)
    }

    private func confirmReplaceIfNeeded(completion: @escaping (Bool) -> Void) {
        webView.evaluateJavaScript("window.FlashMaskP0?.needsReplaceConfirmation?.() === true") { [weak self] value, error in
            guard let self else { return }
            let needed = error != nil || (value as? Bool == true)
            if !needed {
                completion(true)
                return
            }
            if let handler = self.confirmReplaceHandler {
                completion(handler(true))
                return
            }
            completion(self.presentReplaceConfirmation())
        }
    }

    private func presentReplaceConfirmation() -> Bool {
        let chinese = resolvedFlashMaskLanguage() == "zh"
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = chinese ? "更换图片将清除当前圈选和说明" : "Replacing the image clears the current selections and notes"
        alert.informativeText = chinese ? "只有新图片准备成功后，才会清除当前内容。取消可继续编辑。" : "Your current work is kept until the new image is ready. Cancel to keep editing."
        alert.addButton(withTitle: chinese ? "取消" : "Cancel")
        alert.addButton(withTitle: chinese ? "更换图片" : "Replace Image")
        return alert.runModal() == .alertSecondButtonReturn
    }

    @discardableResult
    func openExternalDestination(_ destination: String) -> Bool {
        guard let url = flashMaskExternalURL(destination: destination, language: resolvedFlashMaskLanguage()) else {
            return false
        }
        let opened = openURLHandler?(url) ?? NSWorkspace.shared.open(url)
        if !opened {
            let chinese = resolvedFlashMaskLanguage() == "zh"
            presentPasteNotice(
                title: chinese ? "无法打开链接" : "Couldn’t open the link",
                body: chinese
                    ? "系统未能打开该页面。当前图片、圈选和说明已保留。"
                    : "The page could not be opened. Your image, outlines and notes are unchanged."
            )
        }
        return opened
    }

    private func presentPasteNotice(title: String, body: String) {
        if let handler = pasteNoticeHandler {
            handler(title, body)
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: resolvedFlashMaskLanguage() == "zh" ? "好" : "OK")
        alert.runModal()
    }

    @discardableResult
    private func invalidateInFlightPaste() -> UInt64 {
        pasteGeneration += 1
        if let pending = pendingCreatedScreenshot {
            flashMaskDeleteIfExists(pending)
            pendingCreatedScreenshot = nil
        }
        return pasteGeneration
    }

    private func importPastedRaster(_ data: Data) {
        let generation = invalidateInFlightPaste()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let decoded = flashMaskDecodeRasterData(data)
            DispatchQueue.main.async {
                guard let self, self.pasteGeneration == generation else { return }
                guard let decoded else {
                    self.presentPasteNotice(
                        title: resolvedFlashMaskLanguage() == "zh" ? "图片无法解码" : "We couldn’t open this image",
                        body: resolvedFlashMaskLanguage() == "zh" ? "当前圈选和说明已保留。" : "Your current outlines and notes are unchanged."
                    )
                    return
                }
                self.confirmReplaceIfNeeded { confirmed in
                    guard self.pasteGeneration == generation else { return }
                    guard confirmed else { return }
                    self.saveDecodedPaste(decoded, generation: generation)
                }
            }
        }
    }

    private func saveDecodedPaste(_ decoded: FlashMaskDecodedRaster, generation: UInt64) {
        let directory = screenshotDirectoryOverride ?? flashMaskScreenshotDirectoryURL()
        guard let directory else {
            offerAlternatePasteSave(decoded, generation: generation, errorText: resolvedFlashMaskLanguage() == "zh" ? "系统下载目录不可用。" : "The Downloads folder is unavailable.")
            return
        }
        do {
            let url = try flashMaskSaveScreenshotPNG(decoded, directory: directory)
            guard pasteGeneration == generation else {
                flashMaskDeleteIfExists(url)
                return
            }
            pendingCreatedScreenshot = url
            _ = beginImport(url, origin: "clipboard-paste", pathDelay: 0, skipReplaceConfirmation: true)
        } catch {
            offerAlternatePasteSave(decoded, generation: generation, errorText: error.localizedDescription)
        }
    }

    private func offerAlternatePasteSave(_ decoded: FlashMaskDecodedRaster, generation: UInt64, errorText: String) {
        guard pasteGeneration == generation else { return }
        let chinese = resolvedFlashMaskLanguage() == "zh"
        if let handler = chooseAlternateSaveHandler {
            guard let url = handler() else { return }
            finishAlternatePasteSave(decoded, generation: generation, destination: url, hasImplicitScope: false)
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = chinese ? "截图未能保存" : "Screenshot could not be saved"
        alert.informativeText = chinese
            ? "无法写入下载 / Flash Mask。当前图片、圈选和说明已保留。可以仅为这一次另选位置。\n\(errorText)"
            : "Could not write to Downloads / Flash Mask. Your image, outlines and notes are unchanged. Choose another location for this save only.\n\(errorText)"
        alert.addButton(withTitle: chinese ? "取消" : "Cancel")
        alert.addButton(withTitle: chinese ? "另选位置" : "Choose Location")
        guard alert.runModal() == .alertSecondButtonReturn, pasteGeneration == generation else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = flashMaskScreenshotFileName()
        flashMaskApplyOwnedFilePanelStrings(panel, isOpen: false)
        panel.begin { [weak self] result in
            guard let self, self.pasteGeneration == generation else {
                if result == .OK, let url = panel.url {
                    SecurityScopedFileAccess(url: url, hasImplicitScope: true).release()
                }
                return
            }
            guard result == .OK, let url = panel.url else { return }
            self.finishAlternatePasteSave(decoded, generation: generation, destination: url, hasImplicitScope: true)
        }
    }

    private func finishAlternatePasteSave(
        _ decoded: FlashMaskDecodedRaster,
        generation: UInt64,
        destination: URL,
        hasImplicitScope: Bool
    ) {
        let access = SecurityScopedFileAccess(url: destination, hasImplicitScope: hasImplicitScope)
        let directory = destination.deletingLastPathComponent()
        let name = destination.lastPathComponent
        do {
            let url = try flashMaskSaveScreenshotPNG(decoded, directory: directory, makeName: { name })
            guard pasteGeneration == generation else {
                flashMaskDeleteIfExists(url)
                access.release()
                return
            }
            pendingCreatedScreenshot = url
            _ = beginImport(url, origin: "clipboard-paste", pathDelay: 0, access: access, skipReplaceConfirmation: true)
        } catch {
            access.release()
            presentPasteNotice(
                title: resolvedFlashMaskLanguage() == "zh" ? "截图未能保存" : "Screenshot could not be saved",
                body: error.localizedDescription
            )
        }
    }

    deinit {
        for nonce in Array(imports.keys) { releaseImport(nonce) }
    }

    private func callJavaScript(_ function: String, object: [String: Any], completion: ((Error?) -> Void)? = nil) {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: data, encoding: .utf8) else {
            completion?(NSError(domain: "FlashMask", code: 3, userInfo: nil))
            return
        }
        webView.evaluateJavaScript("\(function)(\(json))") { _, error in completion?(error) }
    }

    private func evaluateObject(_ expression: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        webView.evaluateJavaScript("JSON.stringify(\(expression))") { value, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let text = value as? String,
                  let data = text.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(NSError(domain: "FlashMask", code: 2, userInfo: nil)))
                return
            }
            completion(.success(object))
        }
    }
}

private enum FlashMaskSettingsChrome {
    static let background = NSColor(srgbRed: 18 / 255, green: 23 / 255, blue: 27 / 255, alpha: 1)
    static let text = NSColor(srgbRed: 243 / 255, green: 245 / 255, blue: 246 / 255, alpha: 1)
    static let secondary = NSColor(srgbRed: 162 / 255, green: 170 / 255, blue: 177 / 255, alpha: 1)
    static let line = NSColor(srgbRed: 48 / 255, green: 56 / 255, blue: 62 / 255, alpha: 1)
    static let buttonFill = NSColor(srgbRed: 27 / 255, green: 34 / 255, blue: 40 / 255, alpha: 1)
    static let buttonStroke = NSColor(srgbRed: 61 / 255, green: 71 / 255, blue: 79 / 255, alpha: 1)
    static let yellow = NSColor(srgbRed: 1, green: 229 / 255, blue: 0, alpha: 1)
    static let ink = NSColor(srgbRed: 17 / 255, green: 17 / 255, blue: 17 / 255, alpha: 1)
}

final class FlashMaskSettingsButton: NSButton {
    var fillsYellow = false { didSet { needsDisplay = true } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        bezelStyle = .flexiblePush
        focusRingType = .exterior
        font = .systemFont(ofSize: 12, weight: .medium)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.borderWidth = 1
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        layer?.backgroundColor = (fillsYellow ? FlashMaskSettingsChrome.yellow : FlashMaskSettingsChrome.buttonFill).cgColor
        layer?.borderColor = (fillsYellow ? FlashMaskSettingsChrome.yellow : FlashMaskSettingsChrome.buttonStroke).cgColor
        attributedTitle = NSAttributedString(string: title, attributes: [
            .font: font ?? .systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: fillsYellow ? FlashMaskSettingsChrome.ink : FlashMaskSettingsChrome.text
        ])
        super.draw(dirtyRect)
    }
}

final class FlashMaskSettingsPanel: NSView {
    let iconView = NSImageView()
    let nameLabel = NSTextField(labelWithString: "Flash Mask")
    let versionLabel = NSTextField(labelWithString: "")
    let checkButton = FlashMaskSettingsButton(frame: .zero)
    let resultTitle = NSTextField(labelWithString: "")
    let resultBody = NSTextField(wrappingLabelWithString: "")
    let notesScroll = NSScrollView()
    let storeButton = FlashMaskSettingsButton(frame: .zero)
    let languageLabel = NSTextField(labelWithString: "")
    let languagePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let helpButton = FlashMaskSettingsButton(frame: .zero)
    let feedbackButton = FlashMaskSettingsButton(frame: .zero)
    let websiteButton = NSButton(title: "", target: nil, action: nil)
    let sourceButton = NSButton(title: "", target: nil, action: nil)
    let linkErrorLabel = NSTextField(labelWithString: "")
    let storeErrorLabel = NSTextField(labelWithString: "")
    private let topLine = NSBox()
    private let bottomLine = NSBox()
    private(set) var model = flashMaskSettingsUpdateViewModel(checking: false, outcome: nil, isChinese: true)
    private(set) var isChinese = true
    var onCheck: (() -> Void)?
    var onLanguage: ((String) -> Void)?
    var onHelp: (() -> Void)?
    var onFeedback: (() -> Void)?
    var onWebsite: (() -> Void)?
    var onSource: (() -> Void)?
    var onStore: (() -> Void)?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = FlashMaskSettingsChrome.background.cgColor
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.image = flashMaskSettingsIconImage()
        configureLabel(nameLabel, size: 18, weight: .semibold, color: FlashMaskSettingsChrome.text)
        configureLabel(versionLabel, size: 12, weight: .regular, color: FlashMaskSettingsChrome.secondary)
        configureLabel(resultTitle, size: 12, weight: .regular, color: FlashMaskSettingsChrome.text)
        configureLabel(resultBody, size: 12, weight: .regular, color: FlashMaskSettingsChrome.secondary)
        resultBody.maximumNumberOfLines = 3
        notesScroll.drawsBackground = false
        notesScroll.hasVerticalScroller = true
        notesScroll.borderType = .noBorder
        notesScroll.documentView = resultBody
        configureLabel(languageLabel, size: 13, weight: .regular, color: FlashMaskSettingsChrome.text)
        configureLabel(linkErrorLabel, size: 12, weight: .regular, color: FlashMaskSettingsChrome.text)
        configureLabel(storeErrorLabel, size: 12, weight: .regular, color: FlashMaskSettingsChrome.text)
        languagePopup.bezelStyle = .rounded
        languagePopup.focusRingType = .exterior
        languagePopup.target = self
        languagePopup.action = #selector(changeLanguage)
        checkButton.target = self
        checkButton.action = #selector(check)
        storeButton.target = self
        storeButton.action = #selector(openStore)
        helpButton.target = self
        helpButton.action = #selector(openHelp)
        feedbackButton.target = self
        feedbackButton.action = #selector(openFeedback)
        configureLink(websiteButton, action: #selector(openWebsite))
        configureLink(sourceButton, action: #selector(openSource))
        for line in [topLine, bottomLine] {
            line.boxType = .separator
            line.borderColor = FlashMaskSettingsChrome.line
        }
        for view in [
            iconView, nameLabel, versionLabel, checkButton, resultTitle, notesScroll, storeButton,
            topLine, languageLabel, languagePopup, bottomLine, helpButton, feedbackButton,
            websiteButton, sourceButton, linkErrorLabel, storeErrorLabel
        ] {
            addSubview(view)
        }
        apply(model, isChinese: true, versionLine: "")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func apply(_ model: FlashMaskSettingsUpdateViewModel, isChinese: Bool, versionLine: String) {
        self.model = model
        self.isChinese = isChinese
        versionLabel.stringValue = versionLine
        languageLabel.stringValue = isChinese ? "界面语言" : "Interface language"
        rebuildLanguageItems()
        helpButton.title = isChinese ? "使用帮助" : "User Guide"
        feedbackButton.title = isChinese ? "反馈问题" : "Report an Issue"
        websiteButton.title = isChinese ? "官网 ↗" : "Website ↗"
        sourceButton.title = isChinese ? "源代码 · GitHub ↗" : "Source code · GitHub ↗"
        checkButton.title = model.checkTitle
        checkButton.isEnabled = model.checkEnabled
        resultTitle.stringValue = model.resultTitle ?? ""
        resultTitle.isHidden = model.resultTitle == nil
        resultTitle.font = .systemFont(ofSize: model.kind == "available" ? 13 : 12, weight: model.kind == "available" ? .medium : .regular)
        resultTitle.textColor = model.kind == "latest" ? FlashMaskSettingsChrome.secondary : FlashMaskSettingsChrome.text
        let notes = model.resultBody?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        resultBody.stringValue = notes
        notesScroll.isHidden = notes.isEmpty
        storeButton.title = model.storeTitle ?? ""
        storeButton.fillsYellow = model.storeIsPrimary
        storeButton.isHidden = model.storeTitle == nil
        storeErrorLabel.isHidden = true
        needsLayout = true
    }

    func showLinkOpenFailed() {
        linkErrorLabel.stringValue = isChinese ? "未能打开页面，请重试。" : "Couldn’t open the page. Try again."
        linkErrorLabel.isHidden = false
        needsLayout = true
    }

    func showStoreOpenFailed() {
        storeErrorLabel.stringValue = isChinese ? "未能打开 App Store，请重试。" : "Couldn’t open the App Store. Try again."
        storeErrorLabel.isHidden = false
        needsLayout = true
    }

    func clearOpenErrors() {
        linkErrorLabel.isHidden = true
        storeErrorLabel.isHidden = true
        needsLayout = true
    }

    func preferredContentHeight() -> CGFloat {
        layoutSubtreeIfNeeded()
        let linkBottom = linkErrorLabel.isHidden ? sourceButton.frame.maxY : linkErrorLabel.frame.maxY
        return max(296, linkBottom + 28)
    }

    func snapshot() -> [String: Any] {
        [
            "kind": model.kind,
            "check": checkButton.title,
            "checkEnabled": checkButton.isEnabled,
            "resultTitle": resultTitle.isHidden ? "" : resultTitle.stringValue,
            "resultBody": notesScroll.isHidden ? "" : resultBody.stringValue,
            "store": storeButton.isHidden ? "" : storeButton.title,
            "storePrimary": storeButton.fillsYellow,
            "language": languagePopup.titleOfSelectedItem ?? "",
            "help": helpButton.title,
            "feedback": feedbackButton.title,
            "website": websiteButton.title,
            "source": sourceButton.title,
            "version": versionLabel.stringValue,
            "hasScreenshotCopy": [
                versionLabel.stringValue, resultTitle.stringValue, resultBody.stringValue,
                helpButton.title, feedbackButton.title, websiteButton.title, sourceButton.title
            ].joined().contains("截图") || sourceButton.title.contains("Downloads"),
            "linkError": linkErrorLabel.isHidden ? "" : linkErrorLabel.stringValue,
            "storeError": storeErrorLabel.isHidden ? "" : storeErrorLabel.stringValue,
            "width": bounds.width,
            "height": bounds.height
        ]
    }

    override func layout() {
        super.layout()
        let side: CGFloat = 28
        let width = max(0, bounds.width - side * 2)
        var y: CGFloat = 28
        iconView.frame = NSRect(x: side, y: y + 4, width: 32, height: 28)
        nameLabel.frame = NSRect(x: side + 44, y: y, width: 260, height: 22)
        versionLabel.frame = NSRect(x: side + 44, y: y + 22, width: 260, height: 16)
        checkButton.frame = NSRect(x: bounds.width - side - 186, y: y + 5, width: 186, height: 30)
        y += 44
        if !resultTitle.isHidden {
            y += 12
            let titleWidth = storeButton.isHidden ? width : width - 198
            resultTitle.preferredMaxLayoutWidth = titleWidth
            let titleHeight = max(16, resultTitle.intrinsicContentSize.height)
            resultTitle.frame = NSRect(x: side, y: y, width: titleWidth, height: titleHeight)
            if !storeButton.isHidden {
                storeButton.frame = NSRect(x: bounds.width - side - 186, y: y - 2, width: 186, height: 30)
            }
            y += max(titleHeight, storeButton.isHidden ? 0 : 30)
        }
        if !notesScroll.isHidden {
            y += 8
            resultBody.preferredMaxLayoutWidth = width
            resultBody.frame.size.width = width
            resultBody.sizeToFit()
            let notesHeight = min(72, max(16, resultBody.fittingSize.height))
            notesScroll.frame = NSRect(x: side, y: y, width: width, height: notesHeight)
            resultBody.frame = NSRect(x: 0, y: 0, width: width, height: max(notesHeight, resultBody.fittingSize.height))
            y += notesHeight
        }
        if !storeErrorLabel.isHidden {
            y += 8
            storeErrorLabel.frame = NSRect(x: side, y: y, width: width, height: 16)
            y += 16
        }
        y += 16
        topLine.frame = NSRect(x: side, y: y, width: width, height: 1)
        y += 17
        languageLabel.frame = NSRect(x: side, y: y + 6, width: 200, height: 18)
        languagePopup.frame = NSRect(x: bounds.width - side - 224, y: y, width: 224, height: 30)
        y += 38
        bottomLine.frame = NSRect(x: side, y: y, width: width, height: 1)
        y += 23
        helpButton.frame = NSRect(x: side, y: y, width: 246, height: 30)
        feedbackButton.frame = NSRect(x: side + 258, y: y, width: 246, height: 30)
        y += 46
        websiteButton.sizeToFit()
        sourceButton.sizeToFit()
        let linksWidth = websiteButton.frame.width + 24 + sourceButton.frame.width
        let linksX = side + max(0, (width - linksWidth) / 2)
        websiteButton.frame = NSRect(x: linksX, y: y, width: websiteButton.frame.width, height: 18)
        sourceButton.frame = NSRect(x: websiteButton.frame.maxX + 24, y: y, width: sourceButton.frame.width, height: 18)
        y += 22
        if !linkErrorLabel.isHidden {
            linkErrorLabel.frame = NSRect(x: side, y: y, width: width, height: 16)
        }
    }

    private func configureLabel(_ field: NSTextField, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.backgroundColor = .clear
        field.isBezeled = false
        field.isEditable = false
        field.drawsBackground = false
        field.lineBreakMode = .byWordWrapping
    }

    private func configureLink(_ button: NSButton, action: Selector) {
        button.isBordered = false
        button.bezelStyle = .inline
        button.font = .systemFont(ofSize: 12, weight: .regular)
        button.contentTintColor = FlashMaskSettingsChrome.secondary
        button.focusRingType = .exterior
        button.target = self
        button.action = action
    }

    private func rebuildLanguageItems() {
        let titles = isChinese
            ? ["跟随系统", "中文", "English"]
            : ["Use System Language", "Chinese", "English"]
        let current = languagePopup.indexOfSelectedItem
        let previousAction = languagePopup.action
        languagePopup.action = nil
        languagePopup.removeAllItems()
        languagePopup.addItems(withTitles: titles)
        if (0..<titles.count).contains(current) {
            languagePopup.selectItem(at: current)
        }
        languagePopup.action = previousAction
    }

    func selectLanguagePreference(_ preference: String) {
        let values = ["system", "zh", "en"]
        languagePopup.selectItem(at: values.firstIndex(of: preference) ?? 0)
    }

    @objc private func check() { onCheck?() }
    @objc private func changeLanguage() {
        let values = ["system", "zh", "en"]
        let index = languagePopup.indexOfSelectedItem
        guard (0..<values.count).contains(index) else { return }
        onLanguage?(values[index])
    }
    @objc private func openHelp() { onHelp?() }
    @objc private func openFeedback() { onFeedback?() }
    @objc private func openWebsite() { onWebsite?() }
    @objc private func openSource() { onSource?() }
    @objc private func openStore() { onStore?() }
}

final class FlashMaskSettingsController: NSObject, NSWindowDelegate {
    let window: NSWindow
    let panel: FlashMaskSettingsPanel
    var onClose: (() -> Void)?
    var restoreWindow: NSWindow?

    override init() {
        panel = FlashMaskSettingsPanel(frame: NSRect(x: 0, y: 0, width: 560, height: 296))
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 296),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = "设置"
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.backgroundColor = FlashMaskSettingsChrome.background
        window.contentView = panel
        window.delegate = self
        window.setContentSize(NSSize(width: 560, height: 296))
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
        if let restoreWindow, restoreWindow.isVisible {
            restoreWindow.makeKeyAndOrderFront(nil)
        }
    }

    func fit() {
        panel.layoutSubtreeIfNeeded()
        let height = panel.preferredContentHeight()
        let top = window.frame.maxY
        window.setContentSize(NSSize(width: 560, height: height))
        var frame = window.frame
        frame.origin.y = top - frame.height
        window.setFrame(frame, display: true)
    }
}

final class FlashMaskAppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var controller: FlashMaskController?
    var updateChecker = FlashMaskUpdateChecker()
    var updateOpenHandler: ((URL) -> Bool)?
    var updatePromptHandler: ((FlashMaskUpdateAlert, @escaping (NSApplication.ModalResponse) -> Void) -> Void)?
    var resourceOpenHandler: ((URL) -> Bool)?
    var shortVersionProvider: () -> String? = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
    var buildNumberProvider: () -> String? = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }
    private(set) var settingsController: FlashMaskSettingsController?
    private var updateGeneration: UInt64 = 0
    private var updateVisibleGeneration: UInt64 = 0
    private var checkingPromptOutstanding = false
    private var lastCompletedOutcome: FlashMaskUpdateOutcome?
    private var lastCompletedCountry: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        guard let resources = Bundle.main.resourceURL else { return }
        let controller = FlashMaskController(pageURL: resources.appendingPathComponent("index.html"))
        controller.onLanguagePreferenceChange = { [weak self] in
            self?.installMainMenu()
            self?.reloadSettingsCopy()
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 780), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Flash Mask"
        window.appearance = NSAppearance(named: .darkAqua)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.backgroundColor = NSColor(red: 8 / 255, green: 12 / 255, blue: 15 / 255, alpha: 1)
        window.contentMinSize = NSSize(width: 900, height: 620)
        window.contentView = controller.webView
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.controller = controller
        self.window = window
        controller.load()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        let settings = settingsController?.window
        return NSApp.windows.contains { $0.isVisible && $0 !== settings } == false
    }

    @objc func showSettings(_ sender: Any?) {
        presentSettings(focusLanguage: true, startCheck: false)
    }

    @objc private func performUndo(_ sender: Any?) {
        controller?.performUndo(sender)
    }

    @objc private func performPaste(_ sender: Any?) {
        controller?.performPaste(sender)
    }

    @objc private func openUserGuide(_ sender: Any?) {
        controller?.openExternalDestination("help")
    }

    @objc private func openFeedback(_ sender: Any?) {
        controller?.openExternalDestination("feedback")
    }

    @objc func checkForUpdates(_ sender: Any?) {
        if updatePromptHandler == nil {
            presentSettings(focusLanguage: false, startCheck: true)
        } else {
            startUpdateCheck()
        }
    }

    private var isChineseInterface: Bool {
        resolvedLanguage(UserDefaults.standard.string(forKey: "FlashMaskLanguage") ?? "system") == "zh"
    }

    private var currentLanguagePreference: String {
        UserDefaults.standard.string(forKey: "FlashMaskLanguage") ?? "system"
    }

    func presentSettings(focusLanguage: Bool, startCheck: Bool) {
        let settings = ensureSettingsController()
        settings.restoreWindow = window
        if let window, settings.window.parent == nil {
            window.addChildWindow(settings.window, ordered: .above)
        }
        reloadSettingsCopy()
        if !settings.window.isVisible {
            settings.window.center()
        }
        settings.window.makeKeyAndOrderFront(nil)
        if focusLanguage {
            settings.window.makeFirstResponder(settings.panel.languagePopup)
        } else {
            settings.window.makeFirstResponder(settings.panel.checkButton)
        }
        if startCheck {
            startUpdateCheck()
        }
    }

    private func ensureSettingsController() -> FlashMaskSettingsController {
        if let settingsController { return settingsController }
        let settings = FlashMaskSettingsController()
        settings.panel.onCheck = { [weak self] in self?.startUpdateCheck() }
        settings.panel.onLanguage = { [weak self] preference in
            self?.controller?.setLanguagePreference(preference) { [weak self] in
                self?.installMainMenu()
                self?.reloadSettingsCopy()
            }
        }
        settings.panel.onHelp = { [weak self] in self?.openSettingsDestination("help") }
        settings.panel.onFeedback = { [weak self] in self?.openSettingsDestination("feedback") }
        settings.panel.onWebsite = { [weak self] in self?.openSettingsDestination("website") }
        settings.panel.onSource = { [weak self] in self?.openSettingsDestination("github") }
        settings.panel.onStore = { [weak self] in self?.openAppStorePage(country: self?.lastCompletedCountry) }
        settings.onClose = { [weak self] in
            guard let self else { return }
            if self.updateChecker.isInFlight {
                self.updateVisibleGeneration = 0
                self.applySettingsModel(checking: false, outcome: self.lastCompletedOutcome)
            }
        }
        settingsController = settings
        return settings
    }

    func reloadSettingsCopy() {
        guard let settingsController else { return }
        settingsController.window.title = isChineseInterface ? "设置" : "Settings"
        settingsController.panel.selectLanguagePreference(currentLanguagePreference)
        applySettingsModel(checking: updateChecker.isInFlight && updateVisibleGeneration != 0, outcome: lastCompletedOutcome)
        settingsController.panel.clearOpenErrors()
        settingsController.fit()
    }

    private func applySettingsModel(checking: Bool, outcome: FlashMaskUpdateOutcome?) {
        guard let settingsController else { return }
        let model = flashMaskSettingsUpdateViewModel(checking: checking, outcome: outcome, isChinese: isChineseInterface)
        let versionLine = flashMaskLocalVersionLine(
            shortVersion: shortVersionProvider(),
            build: buildNumberProvider(),
            isChinese: isChineseInterface
        )
        settingsController.panel.apply(model, isChinese: isChineseInterface, versionLine: versionLine)
        settingsController.fit()
        if checking {
            NSAccessibility.post(
                element: settingsController.panel.checkButton,
                notification: .announcementRequested,
                userInfo: [.announcement: isChineseInterface ? "正在检查更新" : "Checking for updates"]
            )
        } else if let title = model.resultTitle, !title.isEmpty {
            NSAccessibility.post(
                element: settingsController.panel.resultTitle,
                notification: .announcementRequested,
                userInfo: [.announcement: title]
            )
        }
    }

    private func startUpdateCheck() {
        if !updateChecker.isInFlight {
            updateGeneration += 1
        }
        updateVisibleGeneration = updateGeneration
        let generation = updateGeneration
        presentChecking()
        updateChecker.check { [weak self] outcome, country in
            self?.deliverUpdateOutcome(outcome, country: country, generation: generation)
        }
    }

    private func presentChecking() {
        let spec = flashMaskCheckingAlert(isChinese: isChineseInterface)
        if let handler = updatePromptHandler {
            if checkingPromptOutstanding { return }
            checkingPromptOutstanding = true
            handler(spec) { [weak self] response in
                guard let self, self.checkingPromptOutstanding else { return }
                self.checkingPromptOutstanding = false
                if response != .abort {
                    self.updateVisibleGeneration = 0
                }
            }
            return
        }
        applySettingsModel(checking: true, outcome: lastCompletedOutcome)
    }

    private func deliverUpdateOutcome(_ outcome: FlashMaskUpdateOutcome, country: String?, generation: UInt64) {
        guard updateVisibleGeneration == generation else { return }
        updateVisibleGeneration = 0
        lastCompletedOutcome = outcome
        lastCompletedCountry = country
        if checkingPromptOutstanding {
            checkingPromptOutstanding = false
            presentUpdateResult(outcome, country: country)
            return
        }
        presentUpdateResult(outcome, country: country)
    }

    private func presentUpdateResult(_ outcome: FlashMaskUpdateOutcome, country: String?) {
        let spec = flashMaskUpdateAlert(outcome: outcome, isChinese: isChineseInterface)
        if let handler = updatePromptHandler {
            handler(spec) { [weak self] response in
                self?.handleUpdateResultResponse(response, outcome: outcome, country: country, spec: spec)
            }
            return
        }
        applySettingsModel(checking: false, outcome: outcome)
    }

    private func handleUpdateResultResponse(
        _ response: NSApplication.ModalResponse,
        outcome: FlashMaskUpdateOutcome,
        country: String?,
        spec: FlashMaskUpdateAlert
    ) {
        if spec.kind == .available, response == .alertFirstButtonReturn {
            openAppStorePage(country: country)
            return
        }
        if spec.kind == .failed, case .failed(.storefrontUnknown) = outcome {
            if response == .alertFirstButtonReturn {
                openAppStorePage(country: country)
                return
            }
            if response == .alertSecondButtonReturn {
                startUpdateCheck()
            }
            return
        }
        if spec.kind == .failed, response == .alertFirstButtonReturn, spec.buttons.count > 1 {
            startUpdateCheck()
        }
    }

    private func openAppStorePage(country: String?) {
        guard let urls = flashMaskResolvedAppStorePageURLs(countryCode: country) else {
            settingsController?.panel.showStoreOpenFailed()
            presentUpdateNotice(
                title: isChineseInterface ? "无法打开 App Store" : "Couldn’t Open the App Store",
                body: isChineseInterface
                    ? "没有可用的商店地址。"
                    : "No App Store destination is available."
            )
            return
        }
        let open = updateOpenHandler ?? { NSWorkspace.shared.open($0) }
        if open(urls.store) { return }
        if open(urls.https) { return }
        settingsController?.panel.showStoreOpenFailed()
        presentUpdateNotice(
            title: isChineseInterface ? "无法打开 App Store" : "Couldn’t Open the App Store",
            body: isChineseInterface
                ? "系统未能打开商店页面。"
                : "The App Store page could not be opened."
        )
    }

    private func openSettingsDestination(_ destination: String) {
        let language = resolvedLanguage(currentLanguagePreference)
        guard let url = flashMaskExternalURL(destination: destination, language: language) else { return }
        let opened = openResourceURL(url)
        if opened {
            settingsController?.panel.clearOpenErrors()
        } else {
            settingsController?.panel.showLinkOpenFailed()
        }
    }

    private func openResourceURL(_ url: URL) -> Bool {
        if let handler = resourceOpenHandler { return handler(url) }
        if let handler = controller?.openURLHandler { return handler(url) }
        return NSWorkspace.shared.open(url)
    }

    private func presentUpdateNotice(title: String, body: String) {
        let spec = FlashMaskUpdateAlert(
            kind: .notice,
            title: title,
            body: body,
            buttons: [isChineseInterface ? "好" : "OK"]
        )
        if let handler = updatePromptHandler {
            handler(spec) { _ in }
        }
    }

    func installMainMenu() {
        let preference = UserDefaults.standard.string(forKey: "FlashMaskLanguage") ?? "system"
        let systemIsChinese = resolvedLanguage(preference) == "zh"
        let titles = flashMaskMainMenuTitles(isChinese: systemIsChinese)
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem(title: titles.app, action: nil, keyEquivalent: "")
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: titles.app)
        let settingsItem = NSMenuItem(title: systemIsChinese ? "设置…" : "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        let updatesItem = NSMenuItem(
            title: systemIsChinese ? "检查更新…" : "Check for Updates…",
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updatesItem.target = self
        appMenu.addItem(updatesItem)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: systemIsChinese ? "退出 Flash Mask" : "Quit Flash Mask", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu

        let fileMenuItem = NSMenuItem(title: titles.file, action: nil, keyEquivalent: "")
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: titles.file)
        fileMenu.addItem(NSMenuItem(title: systemIsChinese ? "关闭窗口" : "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        fileMenuItem.submenu = fileMenu

        let editMenuItem = NSMenuItem(title: titles.edit, action: nil, keyEquivalent: "")
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: titles.edit)
        let undoItem = NSMenuItem(title: systemIsChinese ? "撤销" : "Undo", action: #selector(performUndo(_:)), keyEquivalent: "z")
        undoItem.target = self
        editMenu.addItem(undoItem)
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: systemIsChinese ? "剪切" : "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: systemIsChinese ? "复制" : "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        let pasteItem = NSMenuItem(title: systemIsChinese ? "粘贴" : "Paste", action: #selector(performPaste(_:)), keyEquivalent: "v")
        pasteItem.target = self
        editMenu.addItem(pasteItem)
        editMenuItem.submenu = editMenu

        let windowMenuItem = NSMenuItem(title: titles.window, action: nil, keyEquivalent: "")
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: titles.window)
        windowMenu.addItem(NSMenuItem(title: systemIsChinese ? "最小化" : "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenuItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        let helpMenuItem = NSMenuItem(title: titles.help, action: nil, keyEquivalent: "")
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: titles.help)
        let userGuideItem = NSMenuItem(
            title: systemIsChinese ? "使用帮助" : "User Guide",
            action: #selector(openUserGuide(_:)),
            keyEquivalent: ""
        )
        userGuideItem.target = self
        helpMenu.addItem(userGuideItem)
        let feedbackItem = NSMenuItem(
            title: systemIsChinese ? "反馈问题" : "Report an Issue",
            action: #selector(openFeedback(_:)),
            keyEquivalent: ""
        )
        feedbackItem.target = self
        helpMenu.addItem(feedbackItem)
        helpMenuItem.submenu = helpMenu
        NSApp.helpMenu = helpMenu
        NSApp.mainMenu = mainMenu
    }

    private func resolvedLanguage(_ preference: String) -> String {
        if preference == "zh" || preference == "en" { return preference }
        return Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? "zh" : "en"
    }
}

func flashMaskResourceURL() -> URL? {
    Bundle.main.resourceURL
}
