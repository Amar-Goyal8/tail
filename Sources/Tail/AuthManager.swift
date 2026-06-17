import Foundation
import Supabase
import AppKit

// Supabase auth for the desktop app. OAuth (Discord/Google) via web auth session,
// email magic-link via the tail:// URL scheme. Session persisted by the SDK.
@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    let client: SupabaseClient
    @Published var signedIn = false
    @Published var email: String?
    @Published var loading = true
    private(set) var accessToken: String?

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
    }

    // OAuth (Discord / Google) — opens a web auth session, returns on callback.
    func signIn(_ provider: Provider) async throws {
        try await client.auth.signInWithOAuth(provider: provider,
                                              redirectTo: URL(string: "tail://auth"))
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
