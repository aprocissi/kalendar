// Settings (§12). Milestone 1 implements General and Accounts; the other tabs exist so the
// window has its final shape.
import AppKit
import KalendarCore
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let accounts: AccountStore
    private let signIn: (String?) -> Void
    private var window: NSWindow?

    init(accounts: AccountStore, signIn: @escaping (String?) -> Void) {
        self.accounts = accounts
        self.signIn = signIn
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(accounts: accounts, signIn: signIn))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Kalendar Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    let accounts: AccountStore
    let signIn: (String?) -> Void

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            AccountsSettings(accounts: accounts, signIn: signIn)
                .tabItem { Label("Accounts", systemImage: "person.crop.circle") }
            NotYet()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            NotYet()
                .tabItem { Label("Events & Tasks", systemImage: "list.bullet") }
            NotYet()
                .tabItem { Label("Calendars", systemImage: "calendar") }
        }
        .frame(width: 480, height: 320)
    }
}

private struct GeneralSettings: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    // Sparkle reads this user default itself and prefers it over the Info.plist value
    @AppStorage("SUEnableAutomaticChecks") private var automaticUpdates = true
    @AppStorage("showAlerts") private var showAlerts = true

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    LaunchAtLogin.set(enabled)
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
            Toggle("Show alerts", isOn: $showAlerts)
            Toggle("Check for updates automatically", isOn: $automaticUpdates)
        }
        .formStyle(.grouped)
    }
}

private struct AccountsSettings: View {
    let accounts: AccountStore
    let signIn: (String?) -> Void

    var body: some View {
        Form {
            Section {
                if accounts.accounts.isEmpty {
                    Text("No Google accounts").foregroundStyle(.secondary)
                }
                ForEach(accounts.accounts) { account in
                    AccountSettingsRow(account: account, accounts: accounts, signIn: signIn)
                }
            }
            Button("Add Account…") { signIn(nil) }
        }
        .formStyle(.grouped)
    }
}

private struct AccountSettingsRow: View {
    let account: AccountStore.Account
    let accounts: AccountStore
    let signIn: (String?) -> Void
    @State private var status = ""

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.email)
                Text(account.needsReauth ? "Needs to sign in again" : status)
                    .font(.caption)
                    .foregroundStyle(account.needsReauth ? .red : .secondary)
            }
            Spacer()
            if account.needsReauth {
                Button("Sign In…") { signIn(account.email) }
            }
            Button("Sign Out") { Task { await accounts.signOut(account.email) } }
        }
        .task(id: account) {
            guard !account.needsReauth else { return }
            status = "Checking…"
            do {
                let n = try await accounts.calendars(for: account.email).count
                status = n == 1 ? "1 calendar" : "\(n) calendars"
            } catch {
                status = error.localizedDescription
            }
        }
    }
}

private struct NotYet: View {
    var body: some View {
        Text("Not available yet.")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
