import AppKit
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
}

func flashMaskMainMenuTitles(isChinese: Bool) -> FlashMaskMainMenuTitles {
    FlashMaskMainMenuTitles(
        app: "Flash Mask",
        file: isChinese ? "文件" : "File",
        edit: isChinese ? "编辑" : "Edit",
        window: isChinese ? "窗口" : "Window"
    )
}

func flashMaskAllowsNavigation(_ url: URL?) -> Bool {
    guard let scheme = url?.scheme?.lowercased() else { return true }
    return ["file", "about", "blob", "data", "flashmask-local"].contains(scheme)
}

func flashMaskNavigationPolicy(_ url: URL?, shouldPerformDownload: Bool) -> WKNavigationActionPolicy {
    guard flashMaskAllowsNavigation(url) else { return .cancel }
    return shouldPerformDownload ? .download : .allow
}

private func resolvedFlashMaskLanguage() -> String {
    let preference = UserDefaults.standard.string(forKey: "FlashMaskLanguage") ?? "system"
    if preference == "zh" || preference == "en" { return preference }
    return Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? "zh" : "en"
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

final class FlashMaskController: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate, WKDownloadDelegate {
    let webView: WKWebView
    var onPageReady: (() -> Void)?
    var onLanguagePreferenceChange: (() -> Void)?

    private let pageURL: URL
    private let imageSchemeHandler = LocalImageSchemeHandler()
    private var imports: [String: NativeImportTask] = [:]
    private var pageReady = false
    private var pendingDroppedFile: (url: URL, access: SecurityScopedFileAccess)?
    private var showingFailurePage = false
    private let downloadStates = MaskDownloadStateMachine()

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
        if persist {
            UserDefaults.standard.set(supportedPreference, forKey: "FlashMaskLanguage")
        }
        let language: String
        if supportedPreference == "system" {
            language = Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? "zh" : "en"
        } else {
            language = supportedPreference
        }
        guard let data = try? JSONSerialization.data(withJSONObject: language, options: .fragmentsAllowed),
              let json = String(data: data, encoding: .utf8) else {
            completion?()
            return
        }
        webView.evaluateJavaScript("window.FlashMaskP0.setLanguage(\(json))") { _, _ in completion?() }
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
            UserDefaults.standard.set(language, forKey: "FlashMaskLanguage")
            onLanguagePreferenceChange?()
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
        let request: [String: Any] = [
            "import_nonce": nonce,
            "file_name": task.url.lastPathComponent,
            "image_url": "flashmask-local://\(nonce)/image",
            "origin": origin
        ]
        callJavaScript("window.FlashMaskP0.beginMacImport", object: request)
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

final class FlashMaskAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var controller: FlashMaskController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        guard let resources = Bundle.main.resourceURL else { return }
        let controller = FlashMaskController(pageURL: resources.appendingPathComponent("index.html"))
        controller.onLanguagePreferenceChange = { [weak self] in self?.installMainMenu() }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 780), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Flash Mask"
        window.appearance = NSAppearance(named: .darkAqua)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.backgroundColor = NSColor(red: 8 / 255, green: 12 / 255, blue: 15 / 255, alpha: 1)
        window.minSize = NSSize(width: 900, height: 620)
        window.contentView = controller.webView
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.controller = controller
        self.window = window
        controller.load()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc private func showSettings(_ sender: Any?) {
        let currentPreference = UserDefaults.standard.string(forKey: "FlashMaskLanguage") ?? "system"
        let systemIsChinese = resolvedLanguage(currentPreference) == "zh"
        let alert = NSAlert()
        alert.messageText = systemIsChinese ? "Flash Mask 设置" : "Flash Mask Settings"
        alert.informativeText = systemIsChinese ? "界面语言" : "Language"
        alert.addButton(withTitle: systemIsChinese ? "完成" : "Done")

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 220, height: 28))
        popup.addItems(withTitles: systemIsChinese ? ["跟随系统", "中文", "English"] : ["Use System Language", "Chinese", "English"])
        let preferences = ["system", "zh", "en"]
        let current = currentPreference
        popup.selectItem(at: preferences.firstIndex(of: current) ?? 0)
        alert.accessoryView = popup
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        controller?.setLanguagePreference(preferences[popup.indexOfSelectedItem]) { [weak self] in self?.installMainMenu() }
    }

    @objc private func performUndo(_ sender: Any?) {
        controller?.performUndo(sender)
    }

    private func installMainMenu() {
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
        editMenu.addItem(NSMenuItem(title: systemIsChinese ? "粘贴" : "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenuItem.submenu = editMenu

        let windowMenuItem = NSMenuItem(title: titles.window, action: nil, keyEquivalent: "")
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: titles.window)
        windowMenu.addItem(NSMenuItem(title: systemIsChinese ? "最小化" : "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenuItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu
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
