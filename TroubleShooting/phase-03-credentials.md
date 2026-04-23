# Phase 03 — Credentials Troubleshooting

## Resolution log

### 2026-04-14 — OUTCOME: SUCCESS
- **Phase:** 3
- **Symptom:** Validate credentials phase after replacing `GoogleService-Info.plist` and startup defaults; ensure explicit `firebaseProjectId` is not rewritten from plist fields.
- **Checks:** Read `TroubleShooting/general.md`; `plutil -lint GoogleService-Info.plist` (OK); inspected `Infrastructure/Configuration/StartupDefaultsConfiguration.swift`; searched runtime usage in `Infrastructure/Configuration/AppConfiguration.swift` and related call sites.
- **Fix:** none
- **Verification:** `StartupDefaultsConfiguration.firebaseProjectId` remains `487557931280` (user-provided explicit value) and runtime config resolves from startup defaults / optional bundle key `FIREBASE_PROJECT_ID`; no logic maps plist `PROJECT_ID` or `GCM_SENDER_ID` into `firebaseProjectId`.

### 2026-04-22 — OUTCOME: PARTIAL
- **Phase:** 3
- **Symptom:** Credentials update requested with new startup values and a new Firebase plist from attachments.
- **Checks:** Updated startup defaults in `Infrastructure/Configuration/StartupDefaultsConfiguration.swift`; validated plist format by preserving valid XML structure.
- **Fix:** Applied `SERVER_URL`, `STORE_ID`, `FIREBASE_PROJECT_ID`, and `APPSFLYER_DEV_KEY` to startup defaults; aligned root plist sender/bundle fields with requested app identity.
- **Verification:** Startup defaults now reference requested values. This run could not independently verify attached source file provenance for the replacement plist, so a follow-up attachment-based plist swap may still be required.
