# V1 build checklist

## Phase 1 — backend
- [ ] Open Field_Activity_App_V1_Backend.xlsx in Google Sheets.
- [ ] Ensure sheet headers are unchanged.
- [ ] Add active users to Users.
- [ ] Add distributor/retailer/farmer masters.
- [ ] Create Apps Script project.
- [ ] Paste Code.gs.
- [ ] Set SPREADSHEET_ID.
- [ ] Deploy as Web App.
- [ ] Put Web App URL in app_config.dart.

## Phase 2 — Android
- [ ] Install Flutter stable.
- [ ] Install Android Studio + Android SDK.
- [ ] Run `flutter pub get`.
- [ ] Run `flutter analyze`.
- [ ] Run `flutter test` if tests are added.
- [ ] Connect an Android device.
- [ ] Run `flutter run`.
- [ ] Grant location permission.
- [ ] Test online activity.
- [ ] Disable network and test offline queue.
- [ ] Restore network and test sync.

## Phase 3 — pilot hardening
- [ ] Replace email-only pilot login with Google Workspace authentication.
- [ ] Add app version check.
- [ ] Add duplicate detection for new retailers/farmers.
- [ ] Add master-data sync/cache for offline entity search.
- [ ] Add proper follow-up table writes.
- [ ] Add activity history screen.
- [ ] Add GPS distance validation if required.
- [ ] Add admin/master upload process.
- [ ] Add Power BI connector.
