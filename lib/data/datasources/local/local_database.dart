import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  throw UnimplementedError('localDatabaseProvider must be overridden in main.dart');
});

class LocalDatabase {
  static const String _attendanceKey = 'offline_attendance';
  static const String _expensesKey = 'offline_expenses';
  static const String _syncQueueKey = 'offline_sync_queue';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ==========================
  // ATTENDANCE
  // ==========================

  Future<void> saveOfflineAttendance(
    Map<String, dynamic> data,
  ) async {
    final existing = await getOfflineAttendance();

    existing.add({
      ...data,
      'saved_at': DateTime.now().toUtc().toIso8601String(),
    });

    await _prefs.setString(
      _attendanceKey,
      jsonEncode(existing),
    );
  }

  Future<List<Map<String, dynamic>>> getOfflineAttendance() async {
    final jsonString = _prefs.getString(_attendanceKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(jsonString) as List;

      return decoded
          .map(
            (e) => Map<String, dynamic>.from(
              e as Map,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearOfflineAttendance() async {
    await _prefs.remove(_attendanceKey);
  }

  // ==========================
  // EXPENSES
  // ==========================

  Future<void> saveOfflineExpense(
    Map<String, dynamic> data,
  ) async {
    final existing = await getOfflineExpenses();

    existing.add({
      ...data,
      'saved_at': DateTime.now().toUtc().toIso8601String(),
    });

    await _prefs.setString(
      _expensesKey,
      jsonEncode(existing),
    );
  }

  Future<List<Map<String, dynamic>>> getOfflineExpenses() async {
    final jsonString = _prefs.getString(_expensesKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(jsonString) as List;

      return decoded
          .map(
            (e) => Map<String, dynamic>.from(
              e as Map,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearOfflineExpenses() async {
    await _prefs.remove(_expensesKey);
  }

  // ==========================
  // GENERIC SYNC QUEUE
  // ==========================

  Future<void> addToSyncQueue({
    required String entityType,
    required String action,
    required Map<String, dynamic> data,
  }) async {
    final queue = await getSyncQueue();

    queue.add({
      'entity_type': entityType,
      'action': action,
      'data': data,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    await _prefs.setString(
      _syncQueueKey,
      jsonEncode(queue),
    );
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final jsonString = _prefs.getString(_syncQueueKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(jsonString) as List;

      return decoded
          .map(
            (e) => Map<String, dynamic>.from(
              e as Map,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearSyncQueue() async {
    await _prefs.remove(_syncQueueKey);
  }

  // ==========================
  // COUNTS
  // ==========================

  Future<int> getPendingCount() async {
    final attendance = await getOfflineAttendance();
    final expenses = await getOfflineExpenses();

    return attendance.length + expenses.length;
  }

  Future<bool> hasPendingSync() async {
    return (await getPendingCount()) > 0;
  }

  // ==========================
  // FULL CLEAR
  // ==========================

  Future<void> clearAllOfflineData() async {
    await clearOfflineAttendance();
    await clearOfflineExpenses();
    await clearSyncQueue();
  }
}
