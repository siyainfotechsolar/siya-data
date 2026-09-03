import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consumer_record.dart';
import 'supabase_service.dart';

enum RealtimeChangeType { insert, update, delete }

class ConsumerRecordChangeEvent {
  final RealtimeChangeType type;
  final ConsumerRecord? record;
  final String recordId;
  final Map<String, dynamic> rawPayload;

  ConsumerRecordChangeEvent({
    required this.type,
    required this.record,
    required this.recordId,
    required this.rawPayload,
  });
}

class RealtimeSyncService {
  static SupabaseClient get _client => SupabaseService.client;
  static RealtimeChannel? _channel;
  static final _eventController = StreamController<ConsumerRecordChangeEvent>.broadcast();

  static Stream<ConsumerRecordChangeEvent> get recordEvents => _eventController.stream;

  /// Start listening to changes on public.consumer_records
  static void initialize() {
    if (_channel != null) return;

    _channel = _client
        .channel('public:consumer_records')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'consumer_records',
          callback: (payload) {
            try {
              final eventType = payload.eventType;
              final newRecordMap = payload.newRecord;
              final oldRecordMap = payload.oldRecord;

              if (eventType == PostgresChangeEvent.insert) {
                final record = ConsumerRecord.fromJson(newRecordMap);
                _eventController.add(
                  ConsumerRecordChangeEvent(
                    type: RealtimeChangeType.insert,
                    record: record,
                    recordId: record.id ?? '',
                    rawPayload: newRecordMap,
                  ),
                );
              } else if (eventType == PostgresChangeEvent.update) {
                final record = ConsumerRecord.fromJson(newRecordMap);
                _eventController.add(
                  ConsumerRecordChangeEvent(
                    type: RealtimeChangeType.update,
                    record: record,
                    recordId: record.id ?? '',
                    rawPayload: newRecordMap,
                  ),
                );
              } else if (eventType == PostgresChangeEvent.delete) {
                final id = oldRecordMap['id'] as String? ?? '';
                _eventController.add(
                  ConsumerRecordChangeEvent(
                    type: RealtimeChangeType.delete,
                    record: null,
                    recordId: id,
                    rawPayload: oldRecordMap,
                  ),
                );
              }
            } catch (e) {
              // ignore: avoid_print
              print('Error processing realtime payload: $e');
            }
          },
        )
        .subscribe();
  }

  /// Unsubscribe from channel
  static void dispose() {
    if (_channel != null) {
      _client.removeChannel(_channel!);
      _channel = null;
    }
  }
}
