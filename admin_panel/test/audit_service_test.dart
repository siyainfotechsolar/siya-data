import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/import_log.dart';

void main() {
  group('ImportLog & AuditLogEntry Tests', () {
    test('ImportLog serializes and deserializes correctly with helpers', () {
      final now = DateTime.now();
      final log = ImportLog(
        id: 'log-1',
        fileName: 'solar_dataset_august.xlsx',
        fileSizeBytes: 2048576, // ~1.95 MB
        totalRows: 500,
        insertedCount: 400,
        updatedCount: 80,
        skippedCount: 20,
        failedCount: 0,
        strategy: 'updateNonEmptyOnly',
        createdAt: now,
        createdBy: 'user-1',
      );

      final json = log.toJson();
      expect(json['file_name'], 'solar_dataset_august.xlsx');
      expect(json['total_rows'], 500);
      expect(json['inserted_count'], 400);
      expect(json['updated_count'], 80);

      expect(log.formattedFileSize, contains('MB'));
      expect(log.strategyLabel, 'Smart Update (Non-Empty)');

      final parsed = ImportLog.fromJson(json);
      expect(parsed.fileName, 'solar_dataset_august.xlsx');
      expect(parsed.totalRows, 500);
      expect(parsed.insertedCount, 400);
    });

    test('AuditLogEntry deserializes from database payload correctly', () {
      final json = {
        'id': 'audit-123',
        'record_id': 'rec-456',
        'consumer_no': 'CN-9999',
        'action': 'UPDATE',
        'field_name': 'Mobile Number',
        'old_value': '9876543210',
        'new_value': '9123456780',
        'source': 'Excel / CSV Import',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'profiles': {'email': 'admin@siyasolar.com'},
      };

      final entry = AuditLogEntry.fromJson(json);
      expect(entry.consumerNo, 'CN-9999');
      expect(entry.fieldName, 'Mobile Number');
      expect(entry.oldValue, '9876543210');
      expect(entry.newValue, '9123456780');
      expect(entry.changerEmail, 'admin@siyasolar.com');
      expect(entry.source, 'Excel / CSV Import');
    });
  });
}
