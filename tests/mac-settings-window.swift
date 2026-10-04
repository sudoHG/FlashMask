import AppKit

@main
struct MacSettingsWindowMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        var failures: [String] = []
        var checks = 0
        func check(_ label: String, _ condition: Bool) {
            checks += 1
            if !condition { failures.append(label) }
        }

        let visible = NSScreen.main!.visibleFrame
        let size = NSSize(width: min(900, visible.width), height: min(620, visible.height))
        let main = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        main.isReleasedWhenClosed = false
        main.setFrame(NSRect(origin: NSPoint(x: visible.maxX - main.frame.width, y: visible.maxY - main.frame.height), size: main.frame.size), display: false)
        main.makeKeyAndOrderFront(nil)
        let delegate = FlashMaskAppDelegate()
        delegate.window = main

        func settingsFrame() -> NSRect { delegate.settingsController!.window.frame }
        func checkCentered(_ label: String) {
            let frame = settingsFrame()
            check("\(label)-visible", delegate.settingsController!.window.isVisible)
            check("\(label)-attached", delegate.settingsController!.window.parent === main)
            check("\(label)-centered-x", abs(frame.midX - main.frame.midX) <= 1)
            check("\(label)-centered-y", abs(frame.midY - main.frame.midY) <= 1)
            check("\(label)-on-screen", visible.insetBy(dx: -1, dy: -1).contains(frame))
        }

        // First open: centered over the main window, not left at the window's creation origin.
        delegate.presentSettings(focusLanguage: true, startCheck: false)
        checkCentered("first-open")
        let first = settingsFrame()

        // Showing settings again while it is open keeps the position the user sees.
        delegate.settingsController!.window.setFrameOrigin(NSPoint(x: first.minX - 40, y: first.minY - 30))
        let moved = settingsFrame()
        delegate.presentSettings(focusLanguage: false, startCheck: false)
        check("reopen-while-visible-keeps-position", settingsFrame() == moved)

        // Closing and reopening after the main window moved follows the main window.
        delegate.settingsController!.window.close()
        main.setFrameOrigin(NSPoint(x: visible.minX, y: visible.minY))
        delegate.presentSettings(focusLanguage: true, startCheck: false)
        checkCentered("reopen-after-close")

        // A main window partly off screen still gets a fully visible settings window.
        delegate.settingsController!.window.close()
        main.setFrameOrigin(NSPoint(x: visible.minX - main.frame.width * 0.8, y: visible.minY - main.frame.height * 0.8))
        delegate.presentSettings(focusLanguage: true, startCheck: false)
        check("edge-visible", delegate.settingsController!.window.isVisible)
        check("edge-on-screen", visible.insetBy(dx: -1, dy: -1).contains(settingsFrame()))

        let result: [String: Any] = [
            "ok": failures.isEmpty,
            "checks": checks,
            "failures": failures,
            "visible_frame": NSStringFromRect(visible),
            "first_frame": NSStringFromRect(first)
        ]
        let data = try! JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }
}
