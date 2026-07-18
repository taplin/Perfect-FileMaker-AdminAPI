/// Pure selection logic: given a full client list and configured
/// thresholds, decides which CWP clients are candidates for disconnect.
///
/// No I/O, no dry-run awareness — callers (see `CWPSessionJanitor`) decide
/// whether to actually disconnect a candidate; this type only ever computes
/// the candidate set.
///
/// Being over `maxSessions` is the ONLY trigger for considering a disconnect
/// at all (`nil`/`0` disables the janitor entirely — it never selects
/// anything). A session's age alone is never sufficient reason to kill it:
/// live testing found that a session simply being old is a poor proxy for
/// "stuck", since genuinely slow-but-healthy pages can legitimately hold a
/// session open past any reasonable-looking duration threshold. Duration
/// only narrows down *which* of the over-the-limit sessions actually get
/// disconnected:
///
/// 1. Compute `excess = cwpClients.count - maxSessions`. If not positive,
///    nothing is selected — being under the limit is never actionable.
/// 2. The `excess` OLDEST clients (by duration, descending) are "over the
///    limit". `durationThresholdSeconds` (`nil`/`0` disables this filter)
///    then narrows that set down to only the ones that are ALSO older than
///    the threshold — an over-the-limit session that hasn't been open long
///    is still spared.
///
/// The result never drops the surviving CWP count below `minFloor`: if the
/// candidate set would do that, the youngest-duration candidates are
/// dropped first until the floor holds.
///
/// Note: a newly-created CWP connection doesn't appear in `GET /clients`
/// immediately (there's a short server-side propagation delay, confirmed
/// live) — a non-issue here, since this selector only ever targets the
/// oldest sessions in an over-limit excess, never a brand-new connection.
public enum CWPSessionSelector {
    public static func selectCandidates(
        allClients: [FMAdminClientInfo],
        cwpTypeValue: String,
        durationThresholdSeconds: Int?,
        maxSessions: Int?,
        minFloor: Int
    ) -> (cwpClients: [FMAdminClientInfo], candidates: [FMAdminClientInfo]) {
        let cwpClients = allClients.filter { $0.appType == cwpTypeValue }
        // Oldest-first (longest duration first) — this is the order the
        // over-limit excess is drawn from, and also the order candidates
        // are trimmed from when respecting minFloor.
        let sortedByAge = cwpClients.sorted { ($0.connectDurationSeconds ?? 0) > ($1.connectDurationSeconds ?? 0) }

        guard let maxSessions, maxSessions > 0, cwpClients.count > maxSessions else {
            return (cwpClients, [])
        }
        let excess = cwpClients.count - maxSessions
        let overLimit = Array(sortedByAge.prefix(excess))

        var candidates: [FMAdminClientInfo]
        if let durationThresholdSeconds, durationThresholdSeconds > 0 {
            candidates = overLimit.filter { ($0.connectDurationSeconds ?? 0) > durationThresholdSeconds }
        } else {
            candidates = overLimit
        }

        // Never select below minFloor surviving sessions: if the candidate
        // set would leave fewer than minFloor CWP clients standing, drop the
        // YOUNGEST candidates (least urgent) first until the floor holds.
        // `candidates` is already oldest-first (a filtered sub-sequence of
        // `overLimit`, itself a prefix of `sortedByAge`), so `prefix` here
        // keeps the oldest and drops the youngest.
        let maxRemovable = max(0, cwpClients.count - minFloor)
        if candidates.count > maxRemovable {
            candidates = Array(candidates.prefix(maxRemovable))
        }

        return (cwpClients, candidates)
    }
}
