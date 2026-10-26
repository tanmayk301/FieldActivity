# Photo backend design

Photos are separate from Activities.

## Activity_Photos
- Photo_ID
- Activity_ID
- User_ID
- Entity_Type
- Entity_ID
- Photo_URL
- Captured_DateTime
- Latitude
- Longitude
- Sync_Status

## Storage
Google Drive folder:
Field Activity / Visit Photos / YYYY / MM

The app should save the photo locally first. Upload can happen after the Activity row is accepted.

The Apps Script endpoint should:
1. receive the photo as base64 or a multipart-compatible payload,
2. create a Drive file,
3. return the Drive URL,
4. write Activity_Photos row.

For larger files, keep image quality around 70–75% and max width around 1600px.
