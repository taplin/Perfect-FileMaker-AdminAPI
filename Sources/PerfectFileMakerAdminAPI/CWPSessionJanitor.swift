/// Owns one CWP session sweep cycle: fetch clients, select candidates via
/// `CWPSessionSelector`, respect dry-run, disconnect (or log-only), and
/// report results into a `CWPSessionJanitorTracker`.
public enum CWPSessionJanitor {
    /// - Parameters:
    ///   - client: The Admin API client to use for this sweep.
    ///   - durationThresholdSeconds: See `CWPSessionSelector`. `nil`/`0`
    ///     disables this filter (an over-the-limit session is then a
    ///     candidate regardless of its individual age).
    ///   - maxSessions: See `CWPSessionSelector`. `nil`/`0` disables the
    ///     janitor entirely — it never selects anything without this set,
    ///     since being over the limit is the only disconnect trigger.
    ///   - minFloor: Never disconnect below this many surviving CWP sessions.
    ///   - maxDisconnectsPerSweep: Caps how many candidates this single sweep
    ///     acts on, oldest-first — a rate limiter so a big backlog gets
    ///     drained over several sweeps rather than all at once. `nil`/`0`
    ///     disables the cap. Deferred candidates are simply re-evaluated
    ///     (and very likely re-selected) on the next sweep.
    ///   - dryRun: When `true`, candidates are logged but never actually disconnected.
    ///   - tracker: Recorded into via `finish(...)` on every sweep, success or failure.
    ///   - log: A sink for per-action log lines. Callers plug in their own
    ///     logging (a file, a capture buffer, stdout) — this type has no
    ///     opinion on where log output goes.
    public static func sweep(
        client: FMAdminClient,
        durationThresholdSeconds: Int?,
        maxSessions: Int?,
        minFloor: Int,
        maxDisconnectsPerSweep: Int? = nil,
        dryRun: Bool,
        tracker: CWPSessionJanitorTracker,
        log: @Sendable (String) async -> Void
    ) async {
        guard await tracker.tryBegin() else {
            await log("[cwp-janitor] sweep already in progress, skipping")
            return
        }
        do {
            let allClients = try await client.listClients()
            let (cwpClients, allCandidates) = CWPSessionSelector.selectCandidates(
                allClients: allClients,
                cwpTypeValue: "CWP", // confirmed live 2026-07-17 — see FMAdminModels.swift
                durationThresholdSeconds: durationThresholdSeconds,
                maxSessions: maxSessions,
                minFloor: minFloor
            )
            let candidates: [FMAdminClientInfo]
            if let maxDisconnectsPerSweep, maxDisconnectsPerSweep > 0, allCandidates.count > maxDisconnectsPerSweep {
                candidates = Array(allCandidates.prefix(maxDisconnectsPerSweep))
                await log("[cwp-janitor] capping this sweep to \(maxDisconnectsPerSweep) disconnects (\(allCandidates.count - maxDisconnectsPerSweep) remaining candidates deferred to next sweep)")
            } else {
                candidates = allCandidates
            }
            var disconnectedCount = 0
            for candidate in candidates {
                if dryRun {
                    await log("[cwp-janitor] DRY-RUN would disconnect client \(candidate.id) (duration \(candidate.connectDurationSeconds ?? -1)s)")
                } else {
                    do {
                        try await client.disconnectClient(
                            clientID: candidate.id,
                            messageText: "Disconnected by automated CWP session janitor (stale session cleanup)",
                            graceTime: 0
                        )
                        disconnectedCount += 1
                        await log("[cwp-janitor] disconnected client \(candidate.id) (duration \(candidate.connectDurationSeconds ?? -1)s)")
                    } catch {
                        await log("[cwp-janitor] failed to disconnect client \(candidate.id): \(error)")
                    }
                }
            }
            await tracker.finish(
                consideredCount: cwpClients.count,
                disconnectedCount: disconnectedCount,
                dryRun: dryRun
            )
        } catch {
            // Deliberately no in-loop retry: the Admin Server process has
            // documented real-world flakiness (stale client lists, false
            // session-limit errors under repeated auth), and a tight retry
            // storm risks compounding a transient issue. The caller's own
            // poll loop naturally retries on its next cycle.
            await log("[cwp-janitor] sweep failed: \(error)")
            await tracker.finish(consideredCount: 0, disconnectedCount: 0, dryRun: dryRun, error: "\(error)")
        }
    }
}
