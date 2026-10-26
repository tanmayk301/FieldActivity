# Field Activity App — Android V1

Mobile-first field activity tracking app for:
- Distributor Visits
- Retailer Visits
- Farmer Visits

## Stack
- Flutter Android app
- Google Sheets + Google Apps Script backend
- Offline-first local queue
- GPS capture using `geolocator`
- HTTP sync to Apps Script
- No paid backend required for the V1 pilot

## Important
This package is source code, not an APK. The current build environment does not contain Flutter/Android SDK.

## V1 Flow
Login → Home → Start Activity → Distributor/Retailer/Farmer → Existing/New → Start Visit → GPS + time → Complete → Save locally → Sync to Google Sheets

## Backend setup
1. Open the supplied Field Activity App V1 Backend workbook.
2. Add an Apps Script project from Extensions → Apps Script.
3. Copy `backend/Code.gs` into the Apps Script project.
4. Update `SPREADSHEET_ID` in `Code.gs`.
5. Deploy as Web App:
   - Execute as: Me
   - Who has access: Anyone with the link
6. Copy the Web App URL into `lib/config/app_config.dart`.

For an internal pilot, access is controlled by the Users sheet and Status = Active.
Before a broad production rollout, replace email-only pilot authentication with Google Sign-In / Google Workspace authentication.

## Google Sheet tabs
Users
Distributor_Master
Retailer_Master
Farmer_Master
Activities
Follow_ups
Geography
Audit_Log
README

## Entity rules
- Distributor: existing master only.
- Retailer: existing master + field user can create.
- Farmer: existing master + field user can create.
- Existing entity visit creates a new Activity row.
- New entity gets a unique ID and then immediately opens a visit.
- New entity inherits the logged-in user's geography.
- Activities capture start/end timestamps and GPS.

## Build
Install Flutter stable, then:
flutter pub get
flutter run

For Android release:
flutter build apk --release
