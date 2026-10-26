import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/models.dart';
import 'dart:io';

class ApiService {
Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
  if (AppConfig.apiUrl.contains('PASTE_APPS_SCRIPT')) {
    throw Exception('Backend URL not configured');
  }

  final client = http.Client();

  try {
    final encodedBody = jsonEncode(body);

    final request = http.Request('POST', Uri.parse(AppConfig.apiUrl))
      ..followRedirects = false;

    request.headers['Content-Type'] = 'application/json';
    request.headers['Content-Length'] =
        utf8.encode(encodedBody).length.toString();
    request.body = encodedBody;

    final streamedResponse = await client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 300 &&
        response.statusCode < 400) {
      final location = response.headers['location'];

      if (location != null && location.isNotEmpty) {
        final getResponse = await client.get(Uri.parse(location));

        if (getResponse.statusCode >= 200 &&
            getResponse.statusCode < 300) {
          final data =
              jsonDecode(getResponse.body) as Map<String, dynamic>;

          if (data['ok'] != true) {
            throw Exception(data['error'] ?? 'Unknown error');
          }

          return data;
        }
      }

      // Preserve compatibility with existing requests if the
      // redirected response cannot be retrieved.
      return {'ok': true, 'redirected': true};
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception('Server error ${response.statusCode}');
    }

    final data =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'Unknown error');
    }

    return data;
  } finally {
    client.close();
  }
}

  Future<UserProfile> login(String email) async {
    final uri = Uri.parse(AppConfig.apiUrl).replace(
      queryParameters: {
        'action': 'login',
        'email': email.trim(),
      },
    );

    final response = await http.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Server error ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'Unknown error');
    }

    return UserProfile.fromJson(
      Map<String, dynamic>.from(data['user']),
    );
  }

  Future<List<EntityRecord>> getEntities(String type, UserProfile user) async {
    final uri = Uri.parse(AppConfig.apiUrl).replace(
      queryParameters: {
        'action': 'get_entities',
        'entityType': type,
        'userId': user.userId,
      },
    );

    final response = await http.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Server error ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'Unknown error');
    }

    final list = data['items'] as List? ?? [];

    return list
        .map(
          (e) => EntityRecord.fromJson(
            Map<String, dynamic>.from(e),
            type,
          ),
        )
        .toList();
  }

Future<List<Map<String, dynamic>>> getProducts() async {
  final uri = Uri.parse(AppConfig.apiUrl).replace(
    queryParameters: {
      'action': 'get_products',
    },
  );

  final response = await http.get(uri);

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Server error ${response.statusCode}');
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;

  if (data['ok'] != true) {
    throw Exception(data['error'] ?? 'Unable to load products');
  }

  final list = data['items'] as List? ?? [];

  return list
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}


  Future<List<Map<String, dynamic>>> getProductDemonstrations(
      String userId) async {
    final uri = Uri.parse(AppConfig.apiUrl).replace(queryParameters: {
      'action': 'get_product_demos',
      'userId': userId,
    });
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw Exception('Server error ${response.statusCode}');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['ok'] != true) throw Exception(data['error'] ?? 'Unknown error');
    return (data['items'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  
  Future<EntityRecord> createEntity({
    required String type,
    required UserProfile user,
    required Map<String, dynamic> fields,
  }) async {
    final data = await _post({
      'action': 'create_entity',
      'entityType': type,
      'userId': user.userId,
      'fields': fields,
    });

    return EntityRecord.fromJson(
      Map<String, dynamic>.from(data['item']),
      type,
    );
  }

  Future<Map<String, dynamic>> createActivity(
    Map<String, dynamic> activity,
  ) async {
    return _post({
      'action': 'create_activity',
      'activity': activity,
    });
  }


  
Future<Map<String, dynamic>> submitOrder({
  required UserProfile user,
  required EntityRecord distributor,
  required List<Map<String, dynamic>> items,
}) async {
  return _post({
    'action': 'submit_order',
    'order': {
      'Created_By_User_ID': user.userId,
      'Created_By_Name': user.name,
      'Created_By_Email': user.email,
      'Customer_ID': distributor.id,
      'Customer_Name': distributor.name,
      'items': items,
    },
  });
}


Future<void> saveDayEntry({
  required String userId,
  required String entryType,
  required double odometerKm,
  required DateTime entryTime,
  required double latitude,
  required double longitude,
  required File photo,
}) async {
  final bytes = await photo.readAsBytes();
  final fileName = photo.uri.pathSegments.isNotEmpty
      ? photo.uri.pathSegments.last
      : 'day_entry.jpg';

  final extension = fileName.split('.').last.toLowerCase();
  final mimeType = extension == 'png'
      ? 'image/png'
      : extension == 'webp'
          ? 'image/webp'
          : 'image/jpeg';

  final recordId =
      'DAY-${DateTime.now().millisecondsSinceEpoch}';

  await _post({
    'action': 'save_day_entry',
    'entry': {
      'Record_ID': recordId,
      'User_ID': userId,
      'Entry_Type': entryType,
      'Entry_Date':
          '${entryTime.year}-${entryTime.month.toString().padLeft(2, '0')}-${entryTime.day.toString().padLeft(2, '0')}',
      'Entry_Time': entryTime.toIso8601String(),
      'Odometer_KM': odometerKm,
      'Latitude': latitude,
      'Longitude': longitude,
      'Photo_Data_Base64': base64Encode(bytes),
      'Photo_Mime_Type': mimeType,
      'Photo_File_Name': fileName,
    },
  });
}

}
