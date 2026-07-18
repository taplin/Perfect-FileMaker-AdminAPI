/// Errors thrown by the FileMaker Server Admin API client.
public enum FMAdminError: Error, Sendable {
    /// An HTTP-level failure with status code and response body/message.
    case serverError(Int, String)
    /// HTTP-level authentication failure (401/403) from the Admin API itself.
    case authenticationFailed
    /// The response could not be parsed, or a URL could not be constructed.
    case invalidResponse
}
