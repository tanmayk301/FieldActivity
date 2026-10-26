import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';
import 'local_db.dart';

class SyncService {
  final ApiService api;
  final LocalDb db;

  SyncService(this.api, this.db);

  Future<int> syncPending({
    String? targetActivityId,
    void Function(Map<String, dynamic> response)? onTargetSynced,
    void Function(Object error)? onTargetError,
    void Function(String activityId, String activityType, Object error)? onSyncBlocked,
    void Function()? onOffline,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return 0;
    if (connectivity == ConnectivityResult.none) {
      onOffline?.call();
      return 0;
    }

    int count = 0;
    final rows = await db.pendingActivities();
    for (final row in rows) {
      Map<String, dynamic> payload;
      try {
        payload = Map<String, dynamic>.from(jsonDecode(row['payload'] as String));
      } catch (e) {
        onSyncBlocked?.call('', '', e);
        break;
      }
      try {
        final response = await api.createActivity(payload);
        await db.markSynced(row['id'] as int);
        count++;
        if (targetActivityId != null && '${payload['Activity_ID'] ?? ''}' == targetActivityId) {
          onTargetSynced?.call(response);
        }
      } catch (e) {
        onSyncBlocked?.call(
          '${payload['Activity_ID'] ?? ''}',
          '${payload['Activity_Type'] ?? ''}',
          e,
        );
        if (targetActivityId != null && '${payload['Activity_ID'] ?? ''}' == targetActivityId) {
          onTargetError?.call(e);
        }
        break;
      }
    }
    return count;
  }
}