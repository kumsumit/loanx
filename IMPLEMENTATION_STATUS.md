# LoanX client implementation status

Updated 2026-09-16. This is a current implementation checkpoint, not a launch
certification. The repository-wide feature matrix and closure plan are in the
[feature-gap audit](../docs/feature-gap-audit-2026-09-16.md).

## Current architecture

The client is a Flutter application using Riverpod, encrypted ToStore local
storage, Google Drive app-data backup, PDF/print sharing, local device
authentication, and a Rust bridge. The Rust client communicates with the
separate `../loanx_server/` over framed Protobuf on TLS 1.3 QUIC.

The local schema contains canonical owner, User, Party, Relationship, financial
event, audit, conversation, message, notification, sharing, reminder, and report
tables. Those tables are not evidence of complete features. The user-facing
lender flow still uses the legacy `Loan` entity and floating-point calculations;
the exact financial and connected repositories are largely isolated from UI and
network synchronization.

## User-facing capabilities

| Capability | Status | Notes |
| --- | --- | --- |
| Language, phone OTP and interest onboarding | partial | free local lender workspace no longer requires OTP; borrowers and cloud features use explicit OTP account linking; live provider flow not verified |
| Local lender loan CRUD | implemented on legacy model | add/edit/list/complete/delete, filters and name search |
| Basic pledged material | implemented on legacy model | one material and weight per loan, not first-class collateral lifecycle |
| Receipt printing/PDF/share | implemented on legacy model | not derived from an append-only repayment ledger |
| Google Drive backup/restore | partial | versioned/checksummed archive; live round trip and cross-device key recovery unverified |
| Borrower dashboard | partial | borrower-only routing, explicitly shared local loans, grouped My Lenders, lender notifications and read-only loan details; no live server delivery |
| Borrower financial recording | deliberately unavailable | borrower creation, edit, repayment write and delete are rejected; lenders originate loans |
| Combined lend/borrow experience | partial | distinct lending and read-only borrowing navigation; connected data delivery is incomplete |
| Repayment history/reversal | partial | lender loan-details route exposes exact-currency append-only repayment recording and reversal history; legacy loan balance/closure/receipt remains separate until terms migration |
| Exact deterministic balances | domain only | exact engine is tested but visible flows still use legacy doubles |
| My Lenders / My Borrowers | partial | authorized borrower loans grouped by lender; lender tab groups owner-scoped loans by borrower Party ID and connected/external state; no full relationship actions |
| Connections and verified Party linking | missing | no invitation, consent, confirmation, or safe upgrade flow |
| Client sync queue/multi-device | missing | no durable queue/cursor/apply engine or bridge API |
| Chat/shared resources | repository only | no Flutter chat or connected-resource experience |
| Notifications/reminders | read shell only | no production creation/delivery workflow |
| Documents and collateral photos | missing | no private local attachment/object-storage workflow |
| Subscription activation | missing | plan screen records a preference; it does not purchase or confirm entitlement |
| Marketplace discovery | partial | public profile editing/publishing, locality/city/postal search, pagination, profile view, report and block; no deployed server/SMS/DB end-to-end check or chat |

## Blocking architecture gaps

### Offline session handling

Local routing no longer waits on Rust or remote session restoration, and an
unavailable session no longer clears the verified-phone marker. A free lender
can create/open a local workspace without OTP; the dashboard exposes explicit
account linking for cloud functions. There remains no device verification.

### Identity and ownership

The authenticated bootstrap now persists remote user/workspace/self Party IDs
on the sole local owner, with a mismatch rejecting account switching. The main
loan list and mutations are now owner-scoped. Full account-switch isolation and
every auxiliary repository still need security review and integration tests.

### Financial source of truth

`Money`, `FinancialEngine`, and `RepaymentRepository` provide an exact,
append-only foundation. The active UI instead calculates from `Loan.loanAmount`,
`interestRate`, `settlementAmount`, and completion fields stored as doubles.
Versioned terms, schedule persistence, repayment screens, ledger-derived
closure, and ledger-based receipts are still required.

### Migration and restore

`CanonicalMigration` assigns canonical identity to new records; it does not
migrate an existing SQLCipher/legacy installation into the current ToStore
schema. Required backup-before-migration, source preservation, full backfill,
amount reconciliation, restart recovery, and key migration are absent.

The archive validates structure, size, CRC, and SHA-256. It is not independently
encrypted/authenticated, declares attachments unsupported, and restores the
database before settings without one crash-safe rollback. Cross-device recovery
of the device-generated ToStore encryption keys is not demonstrated.

## Verification on 2026-09-16

| Command/check | Result |
| --- | --- |
| `flutter analyze --no-pub` | passed after borrower routing and owner scoping |
| focused account linking, borrower visibility, local loan scoping, lender discovery and connected repository tests | passed individually |
| `cargo test --offline` in server and client Rust crates | passed; server 4 unit tests and client 1 unit test; no live PostgreSQL integration |
| `env TMPDIR=/private/tmp flutter test --no-pub --reporter compact` | passed, 97 tests including offline-cloud startup, relationship isolation and distinct borrower IDs |
| `env TMPDIR=/private/tmp flutter test --no-pub test/startup_test.dart --reporter compact` | passed, 9 tests; extra settings flush inside fake-async test caused the earlier stall |
| localization ARB comparison | English 517 keys; untranslated keys remain in non-English catalogs |
| CI workflow | Flutter analyze/test and server fmt/test workflows added; GitHub-hosted execution unverified |

New English account-link strings have a temporary runtime overlay because the
localization generator command is currently unavailable in this environment.
Other locale coverage and translation loading/timing still need resolution.
The temporary compiler once returned `No space left on device`; rerunning with
`TMPDIR=/private/tmp` completed. Passing unit tests do not certify release or
live backend integration.

## Next milestones

1. Prove offline startup and cloud linking on devices, including session expiry
   and account switching; widget startup now completes.
2. Integrate exact terms, events, repayments, schedules, balances, and history
   into lender and borrower UI.
3. Finish owner-scoped auxiliary repositories, full external/connected Party
   actions, schedules and the combined experience's connected delivery.
4. Implement validated legacy migration and crash-safe cross-device restore.
5. Expose connected/sync protocol operations through Rust and add the persistent
   client sync queue only after server authorization is corrected.
6. Complete collateral, documents, connections, notifications, entitlements,
   localization, tests, CI, and device/release validation.
