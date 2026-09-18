import 'package:flutter/material.dart';
import '../services/task_service.dart';

class SuggestedCustomerCard extends StatelessWidget {
  final CustomerMatchResult match;
  final VoidCallback onConfirm;
  final VoidCallback onChange;

  const SuggestedCustomerCard({
    super.key,
    required this.match,
    required this.onConfirm,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final customer = match.customer;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: match.isHighConfidence
              ? const Color(0xFF059669)
              : Colors.amber.shade700,
          width: 1.5,
        ),
      ),
      color: match.isHighConfidence
          ? const Color(0xFFECFDF5) // Soft Emerald
          : const Color(0xFFFFFBEB), // Soft Amber
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  match.isHighConfidence
                      ? Icons.verified_user_rounded
                      : Icons.help_outline_rounded,
                  color: match.isHighConfidence
                      ? const Color(0xFF059669)
                      : Colors.amber.shade800,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'SUGGESTED CUSTOMER MATCH',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: match.isHighConfidence
                        ? const Color(0xFF065F46)
                        : Colors.amber.shade900,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: match.isHighConfidence
                        ? const Color(0xFF059669)
                        : Colors.amber.shade800,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    match.confidenceLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              customer.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.bolt, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Consumer No: ${customer.consumerNo}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (customer.mobile != null && customer.mobile!.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.phone, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    customer.mobile!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Reason: ${match.matchReason}',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade700,
              ),
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onChange,
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Change Customer'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Confirm Match'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
