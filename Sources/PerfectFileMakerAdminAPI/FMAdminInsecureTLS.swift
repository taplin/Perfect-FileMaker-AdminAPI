import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Accepts ANY server TLS certificate unconditionally, including self-signed
/// ones — e.g. FileMaker Server's default "Claris Self Signed Certificate
/// (Not for Production Use)". This is an explicit opt-in escape hatch for a
/// known dev/test server, NOT a default: using this against a server whose
/// identity you haven't otherwise verified defeats TLS's whole purpose. See
/// `FMAdminClient.insecureURLSession()`.
public final class FMAdminInsecureTLSDelegate: NSObject, URLSessionDelegate {
    public override init() { super.init() }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

extension FMAdminClient {
    /// A `URLSession` that trusts any server certificate unconditionally —
    /// pass as `urlSession:` to `FMAdminClient.init` when the target is a
    /// known dev/test FileMaker Server using a self-signed certificate.
    /// Never use this for a server reachable over an untrusted network.
    public static func insecureURLSession() -> URLSession {
        URLSession(configuration: .ephemeral, delegate: FMAdminInsecureTLSDelegate(), delegateQueue: nil)
    }
}
