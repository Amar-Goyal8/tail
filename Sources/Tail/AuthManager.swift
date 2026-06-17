import Foundation
import Supabase
import AppKit
import AuthenticationServices

// Supabase auth for the desktop app. OAuth (Discord/Google) via web auth session,
// email magic-link via the tail:// URL scheme. Session persisted by the SDK.
@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    let client: SupabaseClient
    @Published var signedIn = false
    @Published var email: String?
    @Published var loading = true
    @Published var identities: [UserIdentity] = []
    private(set) var accessToken: String?

    // Providers currently linked to this account (e.g. ["google","discord"]).
    var linkedProviders: Set<String> { Set(identities.map(\.provider)) }

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://rnmcmgfhqtizmjfgoguq.supabase.co")!,
            supabaseKey: "sb_publishable_mkwMPg8G5iIZ85O1VEqq1g_EqjHjTBp")
    }

    func bootstrap() async {
        await refresh()
        loading = false
        // keep token fresh as the SDK refreshes the session
        for await state in client.auth.authStateChanges {
            if [.signedIn, .signedOut, .tokenRefreshed, .initialSession].contains(state.event) {
                apply(state.session)
            }
        }
    }

    private func refresh() async { apply(try? await client.auth.session) }

    private func apply(_ session: Session?) {
        accessToken = session?.accessToken
        email = session?.user.email
        signedIn = session != nil
        if session != nil { Task { await loadIdentities() } } else { identities = [] }
    }

    func loadIdentities() async {
        identities = (try? await client.auth.userIdentities()) ?? []
    }

    // Link another provider to the signed-in account (Discord <-> Google).
    @Published var lastError: String?
    func link(_ provider: Provider) async {
        do {
            FileHandle.standardError.write("[tail] linking \(provider)…\n".data(using: .utf8)!)
            try await client.auth.linkIdentity(provider: provider, redirectTo: URL(string: "tail://auth"))
            await loadIdentities()
        } catch {
            lastError = error.localizedDescription
            FileHandle.standardError.write("[tail] link error: \(error)\n".data(using: .utf8)!)
        }
    }

    func unlink(_ identity: UserIdentity) async throws {
        try await client.auth.unlinkIdentity(identity)
        await loadIdentities()
    }

    // OAuth (Discord / Google) — opens a web auth session, returns on callback.
    // Ephemeral session = no shared browser cookies, so it never silently resumes
    // the last account; `prompt=select_account` makes Google show the chooser.
    func signIn(_ provider: Provider) async throws {
        try await client.auth.signInWithOAuth(
            provider: provider,
            redirectTo: URL(string: "tail://auth"),
            queryParams: [("prompt", "select_account")]
        ) { (session: ASWebAuthenticationSession) in
            session.prefersEphemeralWebBrowserSession = true
        }
        await refresh()
    }

    // Email magic link — Supabase emails a tail:// link handled by the app.
    func signInEmail(_ address: String) async throws {
        try await client.auth.signInWithOTP(email: address, redirectTo: URL(string: "tail://auth"))
    }

    // Handle the tail:// deep link (email magic-link callback).
    func handle(url: URL) {
        Task { try? await client.auth.session(from: url); await refresh() }
    }

    func signOut() {
        Task { try? await client.auth.signOut(); await refresh() }
    }
}
