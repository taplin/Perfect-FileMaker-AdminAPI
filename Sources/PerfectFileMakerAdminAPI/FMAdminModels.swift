import Foundation

/// A single connected client, as reported by `GET /fmi/admin/api/v2/clients`.
///
/// Field names confirmed live 2026-07-17 against a real FileMaker Server
/// instance and its own published OpenAPI spec (`/fmi/admin/apidoc/`) — see
/// project memory for the verification trail. One important behavioral
/// note: a newly-created CWP connection does not appear in this list
/// *immediately* — there's a short propagation delay (observed: absent in
/// an immediate post-request check, present roughly 30+ seconds later).
/// This is a non-issue for `CWPSessionSelector`'s actual use (it only ever
/// targets connections *older* than a threshold, so brand-new connections
/// wouldn't be candidates yet regardless), but matters for anyone writing
/// a test or diagnostic that expects to see a connection immediately after
/// creating it.
public struct FMAdminClientInfo: Decodable, Sendable {
    /// Server-assigned client/session identifier — passed back to `disconnectClient(clientID:)`.
    public let id: String
    /// Connection type. Confirmed real values include `"FMPRO"` (FileMaker
    /// Pro/Advanced) and `"CWP"` (Custom Web Publishing) — other client
    /// types (Go, WebDirect, Data API, FMSE, XDBC) are presumed to use
    /// their own distinct strings matching the Admin Console UI's client-
    /// type column, but only these two have been directly observed.
    public let appType: String
    public let appVersion: String?
    public let appLanguage: String?
    public let userName: String?
    public let ipaddress: String?
    public let computerName: String?
    public let macaddress: String?
    public let operatingSystem: String?
    public let status: String?
    public let concurrent: Bool?
    public let teamLicensed: Bool?
    public let extpriv: String?
    /// ISO-8601-ish connection start timestamp, e.g. `"2026-07-17T17:01:05"`
    /// (no explicit timezone offset observed — treat as server-local time).
    public let connectTime: String?
    /// Elapsed connection duration as `"H+:MM:SS"` — the hours component is
    /// NOT clamped to 24 (a 30-hour-old connection reads `"30:30:00"`, not
    /// wrapped), so parse all three components as plain magnitudes, not a
    /// time-of-day. See `connectDurationSeconds` for a pre-parsed value.
    public let connectDuration: String?
    public let guestFiles: [FMAdminGuestFile]?

    public init(
        id: String, appType: String, appVersion: String? = nil, appLanguage: String? = nil,
        userName: String? = nil, ipaddress: String? = nil, computerName: String? = nil,
        macaddress: String? = nil, operatingSystem: String? = nil, status: String? = nil,
        concurrent: Bool? = nil, teamLicensed: Bool? = nil, extpriv: String? = nil,
        connectTime: String? = nil, connectDuration: String? = nil, guestFiles: [FMAdminGuestFile]? = nil
    ) {
        self.id = id
        self.appType = appType
        self.appVersion = appVersion
        self.appLanguage = appLanguage
        self.userName = userName
        self.ipaddress = ipaddress
        self.computerName = computerName
        self.macaddress = macaddress
        self.operatingSystem = operatingSystem
        self.status = status
        self.concurrent = concurrent
        self.teamLicensed = teamLicensed
        self.extpriv = extpriv
        self.connectTime = connectTime
        self.connectDuration = connectDuration
        self.guestFiles = guestFiles
    }

    /// `connectDuration` ("H+:MM:SS") parsed into total elapsed seconds, or
    /// `nil` if the field is missing or malformed. This is what
    /// `CWPSessionSelector` uses for its duration-threshold check.
    public var connectDurationSeconds: Int? {
        guard let connectDuration else { return nil }
        let parts = connectDuration.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return parts[0] * 3600 + parts[1] * 60 + parts[2]
    }
}

/// One database a client has open, as nested under `FMAdminClientInfo.guestFiles`.
public struct FMAdminGuestFile: Decodable, Sendable {
    public let id: String?
    public let filename: String?
    public let accountName: String?
    public let groupName: String?
    public let privsetName: String?
}

/// Top-level decode wrapper for `GET /fmi/admin/api/v2/clients`.
struct FMAdminClientsResponse: Decodable {
    struct Inner: Decodable { let clients: [FMAdminClientInfo] }
    let response: Inner
}
