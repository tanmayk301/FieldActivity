const SPREADSHEET_ID = 'PASTE_GOOGLE_SHEET_ID_HERE';
const PHOTO_ROOT_FOLDER_NAME = 'Field Force Connect - Activity Photos';

function doGet(e) {
  try {
    const params = (e && e.parameter) || {};
    const action = params.action;
    if (action === 'login') return json(login(params.email));
    if (action === 'get_entities') return json(getEntities(params.entityType, params.userId));
    if (action === 'get_product_demos') return json(getProductDemonstrations(params.userId));
    return json({ok:false, error:'Unknown action'});
  } catch (err) {
    return json({ok:false, error:String(err)});
  }
}

function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents || '{}');
    const action = body.action;
    if (action === 'login') return json(login(body.email));
    if (action === 'get_entities') return json(getEntities(body.entityType, body.userId));
    if (action === 'create_entity') return json(createEntity(body.entityType, body.userId, body.fields || {}));
    if (action === 'create_activity') return json(createActivity(body.activity || {}));
    return json({ok:false, error:'Unknown action'});
  } catch (err) {
    return json({ok:false, error:String(err)});
  }
}

function ss() { return SpreadsheetApp.openById(SPREADSHEET_ID); }

function rows(sheetName) {
  const sh = ss().getSheetByName(sheetName);
  if (!sh) throw new Error('Missing sheet: ' + sheetName);
  const values = sh.getDataRange().getValues();
  if (values.length < 2) return [];
  const headers = values[0].map(String);
  return values.slice(1).filter(r => r.some(v => v !== '')).map(r => {
    const o = {};
    headers.forEach((h,i) => o[h] = r[i] ?? '');
    return o;
  });
}

function login(email) {
  const normalized = String(email || '').trim().toLowerCase();
  const user = rows('Users').find(u =>
    String(u.Email || '').trim().toLowerCase() === normalized &&
    String(u.Status || '').toLowerCase() === 'active'
  );
  if (!user) return {ok:false, error:'Active user not found'};
  return {ok:true, user:user};
}

function getUser(userId) {
  const user = rows('Users').find(u => String(u.User_ID) === String(userId));
  if (!user) throw new Error('User not found');
  return user;
}

function inGeo(row, user) {
  // Geography restriction: exact territory is the strongest filter.
  // Fall back to region/district/state when territory is blank.
  if (user.Territory && row.Territory) return String(row.Territory) === String(user.Territory);
  if (user.Region && row.Region) return String(row.Region) === String(user.Region);
  if (user.District && row.District) return String(row.District) === String(user.District);
  if (user.State && row.State) return String(row.State) === String(user.State);
  return false;
}

function getEntities(type, userId) {
  const user = getUser(userId);
  const sheet = type === 'Distributor' ? 'Distributor_Master'
    : type === 'Retailer' ? 'Retailer_Master'
    : 'Farmer_Master';
  const items = rows(sheet).filter(r =>
    String(r.Status || 'Active').toLowerCase() === 'active' && inGeo(r, user)
  );
  return {ok:true, items:items};
}

function fieldActivityHeaders() {
  return [
    'Activity_ID', 'User_ID', 'Activity_Type', 'Activity_Category', 'Entity_Type',
    'Activity_Date', 'Product_Demo_ID', 'Farmer_Name', 'Farmer_Phone', 'Crop',
    'Variety', 'Village', 'Demo_Date', 'Demo_Qty_KG', 'Demo_Acreage',
    'Large_Trial_Plot', 'Distributor_ID', 'Distributor_Name', 'Retailer_ID',
    'Retailer_Name', 'Farmers_Attended', 'Field_Day_Date', 'Photo_URL',
    'Latitude', 'Longitude', 'Created_DateTime'
  ];
}

function fieldActivitiesSheet() {
  const book = ss();
  let sh = book.getSheetByName('Field_Activities');
  if (!sh) sh = book.insertSheet('Field_Activities');
  const expected = fieldActivityHeaders();
  if (sh.getLastRow() === 0 || sh.getLastColumn() === 0) {
    sh.getRange(1, 1, 1, expected.length).setValues([expected]);
  } else {
    const actual = sh.getRange(1, 1, 1, sh.getLastColumn()).getValues()[0].map(String);
    if (actual.join('\u0000') !== expected.join('\u0000')) {
      throw new Error('Field_Activities headers do not match the app schema');
    }
  }
  return sh;
}

function getProductDemonstrations(userId) {
  getUser(userId);
  const sh = ss().getSheetByName('Field_Activities');
  if (!sh || sh.getLastRow() < 2) return {ok:true, items:[]};
  const items = rows('Field_Activities').filter(r =>
    String(r.User_ID) === String(userId) && String(r.Activity_Category) === 'Product Demonstration'
  );
  return {ok:true, items:items};
}

function sheetValue(header, value) {
  if (value === null || value === undefined || value === '') return '';

  // Store date columns as native Google Sheets dates so they sort and filter as dates.
  if (['Activity_Date', 'Demo_Date', 'Field_Day_Date'].indexOf(header) >= 0) {
    if (value instanceof Date) return value;
    const match = String(value).match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (match) return new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
  }

  // Keep the phone's local timestamp exactly as sent. Converting an ISO string
  // to a JavaScript Date here makes Google Sheets apply the script timezone,
  // which can shift the displayed time.
  if (['Created_DateTime', 'Start_Time', 'End_Time'].indexOf(header) >= 0) {
    if (value instanceof Date) return value;
    return String(value).replace('T', ' ').replace(/\.\d+$/, '');
  }
  return value;
}

function photoRootFolder() {
  const properties = PropertiesService.getScriptProperties();
  const savedId = properties.getProperty('PHOTO_ROOT_FOLDER_ID');
  if (savedId) {
    try { return DriveApp.getFolderById(savedId); } catch (_) {}
  }
  const existing = DriveApp.getFoldersByName(PHOTO_ROOT_FOLDER_NAME);
  const root = existing.hasNext() ? existing.next() : DriveApp.createFolder(PHOTO_ROOT_FOLDER_NAME);
  properties.setProperty('PHOTO_ROOT_FOLDER_ID', root.getId());
  return root;
}

function userPhotoFolder(userId) {
  const root = photoRootFolder();
  const folders = root.getFoldersByName(String(userId));
  return folders.hasNext() ? folders.next() : root.createFolder(String(userId));
}

function savePhoto(userId, activityId, base64, mimeType, fileName) {
  if (!base64) return '';
  const bytes = Utilities.base64Decode(base64);
  const safeName = String(fileName || (activityId + '.jpg')).replace(/[^A-Za-z0-9._-]/g, '_');
  const blob = Utilities.newBlob(bytes, mimeType || 'image/jpeg', safeName);
  const file = userPhotoFolder(userId).createFile(blob);
  return file.getUrl();
}

function saveVisitPhotos(activity, user) {
  const files = Array.isArray(activity.Photo_Data_Base64_List) ? activity.Photo_Data_Base64_List : [];
  return files.map((file, index) => savePhoto(
    user.User_ID,
    activity.Activity_ID,
    file.data || file.Photo_Data_Base64,
    file.mimeType || file.Photo_Mime_Type || 'image/jpeg',
    file.fileName || file.Photo_File_Name || (activity.Activity_ID + '_' + (index + 1) + '.jpg')
  )).filter(Boolean);
}

function createFieldActivity(activity, user) {
  const sh = fieldActivitiesSheet();
  const id = String(activity.Activity_ID || '');
  if (id && rows('Field_Activities').some(r => String(r.Activity_ID) === id)) return {ok:true, sheet:'Field_Activities', duplicate:true};

  const record = {};
  fieldActivityHeaders().forEach(h => record[h] = activity[h] ?? '');
  if (!record.Activity_ID) record.Activity_ID = 'ACT-' + new Date().getTime();
  if (!record.Created_DateTime) record.Created_DateTime = new Date();

  if (activity.Photo_Data_Base64) {
    record.Photo_URL = savePhoto(
      user.User_ID,
      record.Activity_ID,
      activity.Photo_Data_Base64,
      activity.Photo_Mime_Type,
      activity.Photo_File_Name || (record.Activity_ID + '.jpg')
    );
  }

  const headers = fieldActivityHeaders();
  sh.appendRow(headers.map(h => sheetValue(h, record[h])));
  audit(user.User_ID, 'CREATE_ACTIVITY', 'Field Activity', record.Activity_ID, JSON.stringify(record));
  return {ok:true, sheet:'Field_Activities'};
}

function nextId(prefix, sheetName, idHeader) {
  const existing = rows(sheetName).map(r => String(r[idHeader] || ''));
  let max = 0;
  existing.forEach(id => {
    const m = id.match(new RegExp('^' + prefix + '-(\\d+)$'));
    if (m) max = Math.max(max, Number(m[1]));
  });
  return prefix + '-' + String(max + 1).padStart(6, '0');
}

function createEntity(type, userId, fields) {
  const user = getUser(userId);
  if (type === 'Distributor') throw new Error('Distributors cannot be created in V1');

  const sheetName = type === 'Retailer' ? 'Retailer_Master' : 'Farmer_Master';
  const idHeader = type === 'Retailer' ? 'Retailer_ID' : 'Farmer_ID';
  const prefix = type === 'Retailer' ? 'RET' : 'FAR';
  const id = nextId(prefix, sheetName, idHeader);
  const sh = ss().getSheetByName(sheetName);
  const optionalHeaders = [
    'Contact_Person', 'Crop', 'Land_Acreage',
    'Distributor_ID', 'Distributor_Name', 'Retailer_ID', 'Retailer_Name'
  ];
  let headers = sh.getRange(1,1,1,sh.getLastColumn()).getValues()[0].map(String);
  const missingHeaders = optionalHeaders.filter(h => headers.indexOf(h) < 0);
  if (missingHeaders.length) {
    sh.getRange(1, headers.length + 1, 1, missingHeaders.length).setValues([missingHeaders]);
    headers = headers.concat(missingHeaders);
  }
  const record = {};

  headers.forEach(h => record[h] = '');
  record[idHeader] = id;
  record[type === 'Retailer' ? 'Retailer_Name' : 'Farmer_Name'] = fields.Name || '';
  record.Mobile = fields.Mobile || '';
  record.Village_Town = fields.Village_Town || fields.Village || '';
  record.Address = fields.Address || '';
  record.Contact_Person = fields.Contact_Person || '';
  record.Crop = fields.Crop || '';
  record.Land_Acreage = fields.Land_Acreage || '';
  record.Distributor_ID = fields.Distributor_ID || '';
  record.Distributor_Name = fields.Distributor_Name || '';
  record.Retailer_ID = fields.Retailer_ID || '';
  record.Retailer_Name = fields.Retailer_Name || '';
  record.Latitude = fields.Latitude || '';
  record.Longitude = fields.Longitude || '';
  record.Status = 'Active';
  record.Created_By = user.User_ID;
  record.Created_Date = new Date();
  record.State = user.State;
  record.District = user.District;
  record.Region = user.Region;
  record.Territory = user.Territory;

  sh.appendRow(headers.map(h => sheetValue(h, record[h])));
  audit(userId, 'CREATE', type, id, JSON.stringify(record));
  return {ok:true, item:record};
}

function createActivity(activity) {
  if (!activity.User_ID) throw new Error('User_ID missing');
  const user = getUser(activity.User_ID);
  if (String(activity.Entity_Type || '') === 'Field Activity') return createFieldActivity(activity, user);

  const destinationByEntity = {
    Distributor: 'Distributor_Visits',
    Retailer: 'Retailer_Visits',
    Farmer: 'Farmer_Visits'
  };
  const sheetName = destinationByEntity[String(activity.Entity_Type || '')];
  if (!sheetName) throw new Error('Unsupported Entity_Type: ' + activity.Entity_Type);

  const book = ss();
  const source = book.getSheetByName('Activities');
  if (!source || source.getLastColumn() < 1) throw new Error('Activities sheet must contain the activity header row');
  let headers = source.getRange(1, 1, 1, source.getLastColumn()).getValues()[0].map(String);
  const photoHeaders = ['Photo_URLs', 'Photo_Upload_Error'];
  const missingSourcePhotoHeaders = photoHeaders.filter(h => headers.indexOf(h) < 0);
  if (missingSourcePhotoHeaders.length) {
    source.getRange(1, headers.length + 1, 1, missingSourcePhotoHeaders.length).setValues([missingSourcePhotoHeaders]);
    headers = headers.concat(missingSourcePhotoHeaders);
  }
  if (headers.indexOf('Activity_Category') < 0) throw new Error('Add Activity_Category to the Activities header row');

  const sh = book.getSheetByName(sheetName);
  if (!sh) throw new Error('Missing sheet: ' + sheetName);
  if (sh.getLastRow() === 0 || sh.getLastColumn() === 0) {
    sh.getRange(1, 1, 1, headers.length).setValues([headers]);
  } else {
    let targetHeaders = sh.getRange(1, 1, 1, sh.getLastColumn()).getValues()[0].map(String);
    const missingTargetPhotoHeaders = photoHeaders.filter(h => targetHeaders.indexOf(h) < 0);
    if (missingTargetPhotoHeaders.length) {
      sh.getRange(1, targetHeaders.length + 1, 1, missingTargetPhotoHeaders.length).setValues([missingTargetPhotoHeaders]);
      targetHeaders = targetHeaders.concat(missingTargetPhotoHeaders);
    }
    if (targetHeaders.join('\u0000') !== headers.join('\u0000')) {
      throw new Error(sheetName + ' headers must match the Activities header row in the same order');
    }
  }

  // Sync can retry after a timeout or a post-write audit error. Treat an existing
  // Activity_ID as success so retries never append duplicate visit rows.
  if (rows(sheetName).some(r => String(r.Activity_ID) === String(activity.Activity_ID || ''))) {
    return {ok:true, sheet:sheetName, duplicate:true};
  }

  const record = {};
  headers.forEach(h => record[h] = activity[h] ?? '');
  if (!record.Activity_ID) record.Activity_ID = 'ACT-' + new Date().getTime();
  if (!record.Created_DateTime) record.Created_DateTime = new Date();
  try {
    record.Photo_URLs = saveVisitPhotos(activity, user).join('\n');
  } catch (err) {
    record.Photo_Upload_Error = String(err);
    console.error('Photo upload failed for ' + record.Activity_ID + ': ' + err);
  }
  sh.appendRow(headers.map(h => sheetValue(h, record[h])));
  try {
    audit(user.User_ID, 'CREATE_ACTIVITY', activity.Entity_Type, activity.Entity_ID, JSON.stringify(record));
  } catch (err) {
    console.error('Visit saved but audit logging failed: ' + err);
  }
  return {ok:true, sheet:sheetName};
}

function audit(userId, action, entityType, entityId, details) {
  const sh = ss().getSheetByName('Audit_Log');
  if (!sh) return;
  sh.appendRow([
    'AUD-' + new Date().getTime(),
    new Date(),
    userId,
    action,
    entityType,
    entityId,
    details
  ]);
}

function json(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}


function authorizeFieldActivityDrive() {
  DriveApp.getRootFolder().getName();
}
