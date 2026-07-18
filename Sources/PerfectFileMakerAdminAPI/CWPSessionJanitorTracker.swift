import Foundation

/// Tracks the in-progress/last-completed state of a CWP session sweep, so a
/// host application can show live status and reject a second concurrent
/// sweep while one is already in flight.
///
/// `tryBegin()` is the only way `isRunning` flips to `true` — actor
/// serialization makes the check-and-set atomic, so two near-simultaneous
/// callers (e.g. an automatic poll loop and a manual "run now" trigger)
/// can't both proceed.
public actor CWPSessionJanitorTracker {
    public private(set) var isRunning = false
    private var lastSweepAt: Date?
    private var lastConsideredCount = 0
    private var lastDisconnectedCount = 0
    private var lastDryRun = true
    private var lastError: String?

    public init() {}

    @discardableResult
    public func tryBegin() -> Bool {
        guard !isRunning else { return false }
        isRunning = true
        return true
    }

    public func finish(consideredCount: Int, disconnectedCount: Int, dryRun: Bool, error: String? = nil) {
        isRunning = false
        lastSweepAt = Date()
        lastConsideredCount = consideredCount
        lastDisconnectedCount = disconnectedCount
        lastDryRun = dryRun
        lastError = error
    }

    /// A human-readable status line — `fallback` is shown before the first sweep ever runs.
    public func statusDescription(fallback: String) -> String {
        if isRunning { return "Sweep running now…" }
        guard let lastSweepAt else { return fallback }
        let when = DateFormatter.localizedString(from: lastSweepAt, dateStyle: .none, timeStyle: .short)
        let mode = lastDryRun ? "dry-run" : "armed"
        var line = "Last sweep (\(mode), \(when)): \(lastConsideredCount) CWP session(s) considered, \(lastDisconnectedCount) disconnected."
        if let lastError { line += " Last error: \(lastError)" }
        return line
    }

    /// A structured snapshot for callers that want individual fields
    /// (e.g. to render separate status-panel rows) rather than one prose sentence.
    public func snapshot() -> (lastSweepAt: Date?, considered: Int, disconnected: Int, dryRun: Bool, error: String?) {
        (lastSweepAt, lastConsideredCount, lastDisconnectedCount, lastDryRun, lastError)
    }
}
