# Field Activity App — V1 UI Specification

## Design direction
Clean, professional, field-friendly Android UI.
- Large touch targets
- Minimal typing
- Clear status indicators
- White cards on a light neutral background
- Primary green accent
- Bottom navigation: Home / Activity / Profile
- Avoid clutter and manager/reporting features in V1

## Screen 01 — Login
- App icon
- Field Activity title
- Company email field
- Continue button
- Small pilot authentication note

## Screen 02 — Home
Header:
- Good morning, {first name}
- Territory • District
- Profile icon
- Sync icon/status

KPI cards:
- Today's visits
- Pending sync

Primary section:
- Start Activity
  - Distributor Visit
  - Retailer Visit
  - Farmer Visit

Secondary:
- Recent activity

## Screen 03 — Entity Selection
- Back + title
- Search field
- Entity cards
- New Retailer / New Farmer CTA where permitted
- Distributor has no create CTA

## Screen 04 — New Entity
- Name
- Mobile
- Village / Town
- Address
- GPS status
- Save & Start Visit

Duplicate rule:
- Mobile number is the only duplicate check.
- If already present, show the existing record instead of creating a new one.

## Screen 05 — Visit In Progress
Top:
- Entity name
- Entity type
- ID
- Started time
- GPS status

Form:
- Purpose
- Outcome
- Remarks

Photos:
- Add Photograph
- Take Photo
- Gallery
- Up to 3 photos
- Thumbnail preview + remove

Bottom:
- Complete Visit

## Screen 06 — Activity History
- Today / Week / Month filters
- Activity type
- Entity
- Duration
- Sync status

## UX principles
- Never require the user to manually enter their geography.
- Start/end time should be system captured.
- GPS should be system captured.
- Save activity locally first if network is unavailable.
- Sync automatically when network returns.
- Do not make a field user wait for cloud upload to complete the visit.
