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
| Language, phone OTP and interest onboarding | partial | screens and QUIC auth client exist; live provider flow not verified |
| Local lender loan CRUD | implemented on legacy model | add/edit/list/complete/delete, filters and name search |
| Basic pledged material | implemented on legacy model | one material and weight per loan, not first-class collateral lifecycle |
| Receipt printing/PDF/share | implemented on legacy model | not derived from an append-only repayment ledger |
| Google Drive backup/restore | partial | versioned/checksummed archive; live round trip and cross-device key recovery unverified |
| Borrower dashboard | early partial | connected-loan cards and scoped local notifications only |
| Borrower external-loan recording | inaccessible | input supports borrowing internally, but Borrower Home has no create action |
| Combined lend/borrow experience | incomplete | `both` currently opens the lender experience only |
| Repayment history/reversal | repository only | no production UI or dashboard integration |
| Exact deterministic balances | domain only | exact engine is tested but visible flows still use legacy doubles |
| My Lenders / My Borrowers | missing | no derived relationship views or party actions |
| Connections and verified Party linking | missing | no invitation, consent, confirmation, or safe upgrade flow |
| Client sync queue/multi-device | missing | no durable queue/cursor/apply engine or bridge API |
| Chat/shared resources | repository only | no Flutter chat or connected-resource experience |
| Notifications/reminders | read shell only | no production creation/delivery workflow |
| Documents and collateral photos | missing | no private local attachment/object-storage workflow |
| Subscription activation | missing | plan screen records a preference; it does not purchase or confirm entitlement |
| Marketplace search | UI shell only | default production search returns no profiles |

## Blocking architecture gaps

### Offline session handling

Application startup attempts remote session restoration before opening the UI.
A failed refresh clears the phone-verification marker, so an offline user can be
sent back to OTP instead of retaining local access. Remote session health must be
separated from the device-local owner and optional app lock.

### Identity and ownership

The authentication response's server user ID is not retained, the server
workspace ID is not discovered, and the self Party is not linked to the account.
The main loan provider also reads all rows and updates/deletes by sequential ID
without requiring `ownerId`. Complete account switching and synchronization are
unsafe until every local read/write is owner scoped.

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
| `flutter analyze --no-pub` | passed; no issues |
| `flutter test --no-pub` | did not complete; stalled after 85 passes at the borrower onboarding startup test |
| `flutter test --no-pub test/startup_test.dart --timeout 30s` | reproduced the same stall; manually stopped |
| localization ARB comparison | English 470 keys; most locales missing 44 English keys, Hindi/Bengali missing 40 |
| CI workflow discovery | none found |

The non-completing test run is a release failure. It also produced repeated
missing-localization-key warnings from newer auth, borrower, and lender-discovery
screens. Historical passing counts and Android builds remain useful historical
evidence, but they do not override the current result.

## Next milestones

1. Preserve offline local access and implement authenticated account/workspace
   bootstrap plus safe owner mapping.
2. Integrate exact terms, events, repayments, schedules, balances, and history
   into lender and borrower UI.
3. Finish owner-scoped Party/Loan repositories, external-loan workflows, My
   Lenders/My Borrowers, and the combined experience.
4. Implement validated legacy migration and crash-safe cross-device restore.
5. Expose connected/sync protocol operations through Rust and add the persistent
   client sync queue only after server authorization is corrected.
6. Complete collateral, documents, connections, notifications, entitlements,
   localization, tests, CI, and device/release validation.
