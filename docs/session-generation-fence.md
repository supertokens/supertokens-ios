# iOS session generation fence

Baseline: `04a4570` (0.5.4). Adapt Android Phase 2, not the archived iOS rewrite.

## Inventory and implementation plan

- `SuperTokensURLProtocol` is the single intercepted transport, including the
  SDK's `/signout`. Its inner `URLSession` bypasses interception. Refresh uses the
  existing generation-scoped flight/callback queue and a separate inner session.
- `SDKStorage` owns Keychain persistence and lazy UserDefaults migration.
  Preserve service/access-group configuration, all six keys, synchronous write
  results, best-effort rollback, and front-token-first removal.
- `FrontToken` and `AntiCSRF` previously maintained independent caches and the
  former dispatched synchronous reads/removals to another queue. Remove those
  independent caches/queue hops; use the coordinator's storage lock throughout.
  No asynchronous partially-installed front-token state remains to wait for.
- Extend the existing `SessionStateCoordinator`, not the network queue: immutable
  `SessionSnapshot`, conditional install/clear, listeners, and legacy-writer
  transactions. Keep request sequencing and refresh coalescing.
- Fence request headers, response commits, refresh clear-on-401, and sign-out
  admission. Retry ordinary unauthorized requests from a fresh snapshot; never
  replay an old sign-out against a replacement.

## Invariants

1. A snapshot reads generation, access, refresh, front, anti-CSRF, and update stamp
   together. `sessionExists` means local presence, not server validity. Reading it
   does not refresh. It exposes secrets; do not log it.
2. One short-held recursive lock serializes SDK storage reads/writes and session
   transactions. Recursion is only synchronous helper composition on the same
   thread. No network, application hook, event handler, or listener runs under it.
   Keychain I/O remains synchronous under this lock. There is no new persisted
   schema or multi-key Keychain transaction: in-process coherence is guaranteed,
   crash consistency and cross-process atomicity are not.
3. Generation is in memory. Install/clear advance it, including accepted mutations
   whose storage operation fails. A rejected CAS or malformed install writes
   nothing. Response clear/new-session/failure advances it; same-session token
   rotations retain it. Request sequence still prevents older rotations winning.
4. Legacy internal storage writers also enter a transaction and invalidate prior
   responses. Writes inside install/response transactions do not advance generation
   separately or expose partially-written snapshots to listeners. Unlike Android,
   these helper writers are not public Swift APIs.
5. Each request/retry builds auth and anti-CSRF headers while reading one coherent
   session. Retrying clears the SDK's old headers; unrelated custom Authorization
   headers retain existing behavior. A generation-stale response cannot mutate
   storage or admit a new lifecycle event. An event admitted earlier can still be
   delivered after replacement. Successful old ordinary responses are still
   delivered to the caller; SDK ownership fencing does not fence application data.
6. Sign-out captures ownership before checking presence/refreshing and before its
   pre-hook. A private URLProtocol request property carries that generation through
   queued transport admission. A stale sign-out completes without replaying against
   replacement credentials; stale completion does not run its post-hook.
7. Listeners receive immutable committed snapshots synchronously outside the lock,
   including token-only updates and failed accepted mutations. They may read,
   install, clear, or unregister. Concurrent commits/reentrant listeners can overtake
   delivery; snapshots are not a globally ordered stream. Use snapshot generation
   for CAS. Removing a listener does not cancel an already-captured callback.
8. Lifecycle admission checks the transition generation under the storage lock, then
   invokes callbacks outside locks. The existing `EventType` handler remains supported,
   but has **no strict stale-entry guarantee**: replacement can complete after
   admission and before the handler begins. An admitted generation-aware listener
   receives the generation of that transition even when delivery is delayed. More
   listeners are rechecked between calls and may be skipped after replacement.
   For clears the event generation is the committed **post-clear** generation; for
   same-session refreshes it remains the session generation. Use it with conditional
   session mutations. It cannot fence unconditional SDK calls, application state,
   navigation, or UI writes. No callback holds the state lock or a delivery gate.
   Refresh application callbacks cannot synchronously join their own refresh flight.

## Public API and compatibility

- `getSessionSnapshot() -> SessionSnapshot` (immutable, `Equatable`).
- `installSession(expectedGeneration:accessToken:refreshToken:frontToken:antiCSRFToken:) -> Bool`.
- `clearSession(expectedGeneration:) -> Bool` (local only).
- `addSessionListener(_:) -> UUID`, `removeSessionListener(_:)`.
- `addLifecycleListener(_:) -> UUID`, `removeLifecycleListener(_:)`: additive
  lifecycle events containing `type` and process-local `generation`, with no raw
  credentials. This is distinct from state-snapshot listeners. Removal prevents
  future admission but cannot cancel a callback already captured for delivery.
  Callback order across threads is not guaranteed. Migrate consumers that take
  session-dependent actions to conditional APIs; the legacy handler cannot do so
  from `EventType` alone.
- Keep unconditional `installSession(...)`, `clearSessionLocally()`, individual
  getters, existing Keychain keys, iOS 13/macOS 12 targets and Swift 5 language mode.
- A false mutation result can mean CAS rejection, invalid input, or storage failure;
  re-read the snapshot. Keychain cleanup can itself fail; false does not mean disk
  is empty. Raw credentials are trusted structurally, not cryptographically verified.
- For an ordinary response carrying a refresh token, matching JWT `sessionHandle`
  claims distinguish a rotation from a replacement. If either claim is unavailable,
  the SDK conservatively treats the response as a replacement. These claims are
  used for local ordering only, never as authentication or verification.
- Generation is not an interprocess fence. Apps/extensions sharing a Keychain
  group must coordinate externally; direct Keychain/UserDefaults writes bypass
  SDK session ownership. Multi-key reads cannot make another process atomic.

## Cookie boundary

iOS has no manual response-cookie storage path to fence. Default inner and outer
`URLSession` cookie handling can save `Set-Cookie` to a shared `HTTPCookieStorage`
before SDK response processing. Generation protects SDK token storage/events, not
that automatic cookie jar. Full stale-cookie isolation requires a separately owned
cookie transport/jar and is out of scope. Header mode remains the default; cookie
mode and old cookie-to-header migration retain this limitation.

## Tests

Use public session APIs and real URLSession/URLProtocol plumbing, with a gated
backend protocol (no sleeps/server required) for late refresh success/401 after
install, ordinary response after clear, and sign-out after install. Also cover CAS
competition, reentrant listeners, replacement retries/CSRF, same-session rotations,
and legacy writers. Keep the existing Node/Core suite as the regression gate.
No new dependencies, CI changes, release, or Rownd/Hub changes.
