import AppKit

// Top-level code runs on the main thread; the delegate is main-actor isolated.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()   // NSApplication holds its delegate weakly; run() never returns
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
