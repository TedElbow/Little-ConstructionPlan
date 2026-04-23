# Phase 2 Troubleshooting (CocoaPods)

## Resolution log

### 2026-04-14 — OUTCOME: SUCCESS
- **Phase:** 2
- **Symptom:** Post-phase verification requested after CocoaPods integration; no active error reproduced.
- **Checks:** Read `TroubleShooting/general.md`; verified `objectVersion = 77` in `BaseProject.xcodeproj/project.pbxproj`; confirmed `Podfile.lock` exists; ran `xcodebuild -list -workspace "BaseProject.xcworkspace"` and validated workspace/schemes including `Pods-PodsShared-BaseProject`.
- **Fix:** none
- **Verification:** All phase-2 minimum checks passed with successful command exit status and expected artifacts present.

### 2026-04-22 — OUTCOME: SUCCESS
- **Phase:** 2
- **Symptom:** CocoaPods install needed after Phase 1 rename and project format normalization.
- **Checks:** Updated root app project `objectVersion` to `77`; attempted `bundle exec pod install` (failed due missing Bundler 4.0.4); attempted `pod install` (failed due locale); reran with UTF-8 locale; verified workspace with `xcodebuild -list -workspace "LittleConstructionPlan.xcworkspace"`.
- **Fix:** Ran `pod install` with `LANG=en_US.UTF-8` and `LC_ALL=en_US.UTF-8`; integrated pods for renamed targets/schemes.
- **Verification:** `LittleConstructionPlan.xcworkspace` loads and lists expected schemes (`LittleConstructionPlan`, `notifications`, `Pods-PodsShared-LittleConstructionPlan`); pod install completed successfully.
