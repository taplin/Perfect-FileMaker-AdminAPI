# Perfect-FileMaker-AdminAPI

A Swift client for the FileMaker Server Admin API (v2) — lists connected
clients and force-disconnects them — plus a policy layer on top, the **CWP
Session Janitor**, that periodically sweeps and disconnects stale/excess
Custom Web Publishing sessions to keep FileMaker Server under its licensed
concurrent-connection cap.

## Status: core dependency

This is **not** a staged or future-integration package. It is depended on
directly by Perfect-Lasso — a Swift reimplementation of the Lasso language,
still in active development and not yet production-ready — which runs the
CWP Session Janitor as a background task against a real, live FileMaker
Server during validation testing. It is confirmed working end-to-end
against that real server: FileMaker Server is licensed for a maximum of
200 concurrent connections, and the Janitor is what keeps stuck/orphaned
CWP sessions from
exhausting that cap.

## Requirements

- Swift tools version **6.2**
- **macOS 26** or later (`platforms: [.macOS(.v26)]`) — no iOS or other
  platform is currently declared

## Dependencies

None. `Package.swift` declares no `dependencies:` array — this is a leaf
package with zero external or in-ecosystem dependencies. It uses only
Foundation / FoundationNetworking and `URLSession` directly, with no
third-party HTTP or JSON layer.

It is also deliberately independent of, and has zero dependency on,
`Perfect-FileMaker` (the classic XML CWP client) or
`Perfect-FileMaker-DataAPI` — a consumer that only needs FileMaker Server
session management can pull in just this package.

## What's here

### Raw Admin API client

- **`FMAdminClient`** — `public struct ... Sendable` wrapping the FileMaker
  Server Admin API v2 over `URLSession`. `listClients()` and
  `disconnectClient(clientID:messageText:graceTime:)`, both `async throws`.
  `disconnectClient` performs a **real** disconnect — there is no built-in
  dry-run; "would I disconnect this" is a policy decision left to the layer
  above (see the Janitor below).
- **`FMAdminSession`** (internal `actor`) — caches the Admin API's
  15-minute bearer token. Re-authenticating on every call is a known
  anti-pattern that can exhaust the session cap on its own, so token caching
  here is safety-relevant, not just an optimization.
- **`FMAdminModels`** — `Decodable`, `Sendable` response types
  (`FMAdminClientInfo`, `FMAdminGuestFile`).
- **`FMAdminError`** — `Error, Sendable`.
- **`FMAdminInsecureTLS`** — an explicit opt-in `URLSessionDelegate`
  (`FMAdminInsecureTLSDelegate`) for trusting self-signed certs, e.g.
  FileMaker Server's default dev certificate. Not marked `Sendable` itself —
  `URLSessionDelegate` conformance has its own thread-safety contract
  independent of Swift's `Sendable` checking. Opt-in only; never the default.

### CWP Session Janitor (policy layer)

- **`CWPSessionSelector`** — pure selection logic. Being over `maxSessions`
  is the *only* disconnect trigger; a `durationThresholdSeconds` filter only
  narrows which of the over-the-limit sessions get picked. Supports a
  `minFloor` (never disconnect below N surviving sessions) and a per-sweep
  disconnect cap so a large backlog drains gradually across sweeps rather
  than all at once.
- **`CWPSessionJanitor`** — runs one sweep: fetch clients → select
  candidates → dry-run-or-disconnect → report into a tracker. No in-loop
  retry on failure by design (the Admin Server has documented real-world
  flakiness; the caller's own poll loop retries on its next cycle).
- **`CWPSessionJanitorTracker`** — `public actor` recording last-sweep state
  (`lastSweepAt`, `considered`, `disconnected`, `dryRun`, `error`) via
  async-safe accessors, and preventing two overlapping sweeps.

## Usage

```swift
import PerfectFileMakerAdminAPI

let client = FMAdminClient(
    host: "filemaker.example.com",
    username: "admin",
    password: "••••••••"
)

let tracker = CWPSessionJanitorTracker()

await CWPSessionJanitor.sweep(
    client: client,
    durationThresholdSeconds: 3600,
    maxSessions: 150,
    minFloor: 20,
    maxDisconnectsPerSweep: 10,
    dryRun: false,
    tracker: tracker,
    log: { print($0) }
)
```

For local development against a self-signed FileMaker Server certificate,
pass a `URLSession` configured with `FMAdminInsecureTLSDelegate` into
`FMAdminClient`'s `urlSession` parameter — this should never be used against
a production server with a real certificate.

## License

Not yet specified.
