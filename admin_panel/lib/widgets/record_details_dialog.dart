import 'package:flutter/material.dart';
import '../models/consumer_record.dart';

class RecordDetailsDialog extends StatelessWidget {
  final ConsumerRecord record;

  const RecordDetailsDialog({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.solar_power, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.name,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Consumer No: ${record.consumerNo}',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 28),
            _buildDetailRow('Application ID', record.applicationId ?? '—'),
            _buildDetailRow('Mobile Number', record.mobile ?? '—'),
            _buildDetailRow('Status', record.status, isStatus: true, theme: theme),
            _buildDetailRow('Address', record.address ?? '—'),
            _buildDetailRow('Remarks', record.remarks ?? '—'),
            _buildDetailRow(
              'Created Date',
              record.createdAt != null
                  ? record.createdAt!.toLocal().toString().split('.')[0]
                  : '—',
            ),
            _buildDetailRow(
              'Last Updated',
              record.updatedAt != null
                  ? record.updatedAt!.toLocal().toString().split('.')[0]
                  : '—',
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false, ThemeData? theme}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          Expanded(
            child: isStatus
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
          ),
        ],
      ),
    );
  }
}
