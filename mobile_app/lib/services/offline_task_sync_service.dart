import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/customer_task.dart';

class OfflineTaskSyncService {
  static const String _queueFileName = 'offline_tasks_queue.json';
  static final List<CustomerTask> _cachedQueue = [];
  static bool _isLoaded = false;

  static Future<File> _getQueueFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_queueFileName');
  }

  /// Initialize and load stored offline tasks into memory
  static Future<List<CustomerTask>> loadQueue() async {
    try {
      final file = await _getQueueFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> list = jsonDecode(content) as List<dynamic>;
          _cachedQueue.clear();
          for (final item in list) {
            if (item is Map) {
              _cachedQueue.add(
                CustomerTask.fromMap(Map<String, dynamic>.from(item)),
              );
            }
          }
        }
      }
      _isLoaded = true;
    } catch (e) {
      debugPrint('Error loading offline tasks queue: $e');
    }
    return List.unmodifiable(_cachedQueue);
  }

  static Future<void> saveQueue() async {
    try {
      final file = await _getQueueFile();
      final list = _cachedQueue.map((t) => t.toMap()).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving offline tasks queue: $e');
    }
  }

  /// Add a task to offline queue and persist immediately
  static Future<void> enqueueTask(CustomerTask task) async {
    if (!_isLoaded) await loadQueue();
    final index = _cachedQueue.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      _cachedQueue[index] = task;
    } else {
      _cachedQueue.add(task);
    }
    await saveQueue();
  }

  /// Remove task once successfully synced to remote database
  static Future<void> dequeueTask(String taskId) async {
    if (!_isLoaded) await loadQueue();
    _cachedQueue.removeWhere((t) => t.id == taskId);
    await saveQueue();
  }

  /// Get list of pending offline tasks
  static Future<List<CustomerTask>> getPendingTasks() async {
    if (!_isLoaded) await loadQueue();
    return _cachedQueue
        .where((t) => t.syncStatus == 'Pending Sync')
        .toList();
  }

  /// Check if there are tasks awaiting synchronization
  static bool get hasPendingTasks =>
      _cachedQueue.any((t) => t.syncStatus == 'Pending Sync');

  static int get pendingCount =>
      _cachedQueue.where((t) => t.syncStatus == 'Pending Sync').length;
}
