# Phase 04 — Brand Assets Troubleshooting

## Resolution log

### 2026-04-14 — OUTCOME: SUCCESS
- **Phase:** 4
- **Symptom:** Validate brand-assets phase after asset set refresh, app icon replacement, and Paytone font wiring.
- **Checks:** Read `TroubleShooting/general.md`; inspected git changes for `Resources/Assets.xcassets/*` and `Resources/Fonts/PaytoneOne-Regular.ttf`; validated all `Resources/Assets.xcassets/**/Contents.json` with Python JSON parse; verified referenced image files exist on disk; checked `BaseProject-Info.plist` contains `UIAppFonts -> Fonts/PaytoneOne-Regular.ttf`; confirmed `Core/Presentation/Theme/AppTypography.swift` uses `PaytoneOne-Regular`; ran `xcodebuild -list -workspace BaseProject.xcworkspace`.
- **Fix:** none
- **Verification:** All Phase 4 target assets are present and structurally valid, font file exists and is registered in plist/typography, and workspace scheme listing succeeds (`BaseProject`, `notifications`).

### 2026-04-22 — OUTCOME: PARTIAL
- **Phase:** 4
- **Symptom:** User requested full brand-assets replacement from attachments (icon/backgrounds/frame/button/font), but attachment files were not accessible as filesystem inputs in this run.
- **Checks:** Inspected workspace for incoming binary asset/font files and prepared canonical mapping targets for Phase 4.
- **Fix:** No safe asset overwrite performed without concrete source binaries.
- **Verification:** Existing asset catalog and font wiring remain unchanged; Phase 4 requires user-provided file paths/attachments retried in-session to complete replacement safely.

### 2026-04-22 — OUTCOME: SUCCESS
- **Phase:** 4
- **Symptom:** Apply provided brand assets with `Logo` explicitly skipped and custom font path provided.
- **Checks:** Mapped user files to canonical assets (`AppIcon`, `InternetBackground`, `InternetFrame`, `LoadingBackground`, `NotificationBackground`, `NotificationButton`); regenerated `AppIcon.appiconset`; verified `Contents.json` for updated sets; resolved font metadata via Spotlight (`kMDItemFonts`) and updated typography/plist wiring.
- **Fix:** Replaced image payloads in canonical imagesets; created `internetFrame.imageset`; removed legacy `frame.imageset`; copied `Resources/Fonts/PlumbSoft.ttf`; updated `LittleConstructionPlan-Info.plist` (`UIAppFonts`) and `Core/Presentation/Theme/AppTypography.swift` to PostScript `PlumbSoft-Black`.
- **Verification:** Compile-only build succeeded (`xcodebuild -scheme "LittleConstructionPlan" -workspace "LittleConstructionPlan.xcworkspace" -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`); updated assets and font file exist.
