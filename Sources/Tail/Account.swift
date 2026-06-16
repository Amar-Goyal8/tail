import Foundation

// Local account identity. Generates a persistent, unguessable token on first
// launch and stores it in UserDefaults. Sent as a Bearer token so the backend
// can tie clips to this account ("my clips"). Real login (Discord OAuth) can
// later replace how this token is obtained without changing the upload flow.
enum Account {
    private static let key = "tail.accountToken"

    static var token: String {
        if let existing = UserDefaults.standard.string(forKey: key), existing.count >= 16 {
            return existing
        }
        let fresh = newToken()
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }

    private static func newToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 24)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return "acct_" + Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
